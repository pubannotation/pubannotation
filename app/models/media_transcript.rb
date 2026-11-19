class MediaTranscript < ApplicationRecord
  # Marks a Block as corresponding to a spoken segment of the media, kept apart from the denotations
  # of real semantic annotations. Its span is what selects it for playback-position highlighting.
  SEGMENT_BLOCK_OBJ = 'AudioSegment'.freeze

  # `medium` is stored directly (not via doc/media_transcription_task) since both associations
  # are optional: a Doc never exists for a no-speech result, and MediaTranscriptionTask can be
  # cleaned up independently (dependent: :nullify). A Doc, once linked, is not severable the
  # same way (Doc has_one :media_transcript, dependent: :destroy).
  belongs_to :medium
  belongs_to :media_transcription_task, optional: true
  belongs_to :doc, optional: true

  # Timed transcript segments (see Segment), chronological and non-overlapping (enforced by Segment);
  # images have none. Changed only through this transcript (e.g. #set_segment_text), so that saving it
  # saves them along with the text and the doc's body rebuilt from them.
  has_many :segments, -> { order(:sort_order) }, autosave: true, inverse_of: :media_transcript

  # `text` is the plain-text Doc body: an image caption, or the speech transcript for audio/video, derived
  # from the segments (see #default_text_from_segments). Blank, though not nil, when Whisper transcribes
  # only non-speech labels such as "(music)".
  validates :text, exclusion: { in: [nil], message: "can't be nil" }
  validates :media_transcription_task_id, uniqueness: true, allow_nil: true
  validates :doc_id, uniqueness: true, allow_nil: true
  validate :doc_has_matching_medium
  validate :segments_unchanged_without_doc, on: :update
  validate :segments_have_speech, on: :update, if: :doc
  validate :segments_keep_time_span, on: :update

  # Records loaded from the database already have their text.
  after_initialize :default_text_from_segments, if: :new_record?

  # Once created, changed segments (e.g. a segment's text edited) rebuild text, and the doc follows them. Not only
  # as text changes, since segments split or merged at a space leave it as it is but span the doc differently.
  before_update :rebuild_text, if: :segments_changing?
  after_update :sync_doc, if: :doc

  # A manually registered audio/video document has one segment covering the whole medium.
  def self.create_from_doc!(doc)
    medium = doc.medium
    raise ArgumentError, "Specified media can't get a transcript." unless medium&.transcribable?

    # Explicit text preserves a body that looks like a Whisper non-speech label.
    create!(
      medium: medium,
      doc: doc,
      text: doc.body,
      segments: [Segment.new(sort_order: 0, text: doc.body, start_ms: 0, end_ms: medium.duration_ms)]
    )
  end

  # Replaces the segments with `new_segments`, each with its sort_order, once saved.
  def replace_segments(new_segments)
    segments.each(&:mark_for_destruction)
    # Through the inverse, each joins `segments` unsaved, as `segments <<` would save it at once.
    new_segments.each { |segment| segment.media_transcript = self }
  end

  # Segments that are actual speech, excluding Whisper's non-speech labels (e.g. "(music)").
  # Kept rather than discarded in `segments`, since the raw transcript may still be useful.
  def speech_segments
    current_segments.select(&:speech?)
  end

  # Whether it has segments, which an image caption's doesn't.
  def segmented?
    current_segments.any?
  end

  # The speech segments' text, each separated from the next by its separator_after (a space, or a line
  # break if it has one after it).
  def speech_text
    *leading, last = speech_segments
    leading.map { |segment| segment.text + segment.separator_after }.join + last&.text.to_s
  end

  # Each speech segment's char offset ({begin:, end:}) into what #speech_text builds from them (one
  # separating char, a space or a line break, between consecutive speech segments, regardless of
  # non-speech segments between them in `segments`), in the same order as #speech_segments, paired with
  # its start_ms.
  def speech_segment_spans
    char_position = 0

    speech_segments.map do |segment|
      char_begin = char_position
      char_end = char_begin + segment.text.length
      char_position = char_end + 1

      { begin: char_begin, end: char_end, start_ms: segment.start_ms }
    end
  end

  # Creates, in `project`, a Block for each speech segment on its doc, which is expected to be already added
  # to `project`.
  def create_segment_blocks!(project)
    ProjectDoc.find_by!(project:, doc:).create_blocks_of(SEGMENT_BLOCK_OBJ, segment_block_spans)
  end

  # generation_model as AudioTranscriptionService.generation_model records it, e.g. "whisper:ggml-base.en".
  def transcribed_by_whisper?
    generation_model.to_s.start_with?('whisper:')
  end

  # Whisper documents can change their body only to follow this transcript.
  def allows_doc_body?(body)
    !transcribed_by_whisper? || text == body
  end

  # Replaces the text of `segment`, leaving its start_ms/end_ms as they are. On save, text and the doc's body
  # are rebuilt to follow (see #rebuild_text and #sync_doc_body). Changed through the same segment among
  # these ones, which may have been reloaded since `segment` was loaded (e.g. as the transcript was locked),
  # so fails for one since replaced, e.g. by #replace_segments, which gives the new ones new ids.
  def set_segment_text(segment, new_text)
    current = current_segments.find { it == segment }
    raise ActiveRecord::RecordNotFound, "No segment with id #{segment.id}." unless current

    # Checked once stripped, since strip also removes chars blank? doesn't count as blank, e.g. "\0".
    stripped_text = new_text&.strip
    raise ArgumentError, "Text is missing." if stripped_text.blank?

    current.text = stripped_text
  end

  # Whether a line break can follow `segment` in the doc's body: a speech segment's can, but the last
  # one's, which nothing follows.
  def line_break_settable_after?(segment)
    segment.speech? && segment != last_speech_segment
  end

  # Changes `segment` by `attributes`, its text and/or whether a line break follows it, and saves it, rebuilding
  # text and the doc's body. Reloads and locks itself first, so a concurrent edit of another segment isn't
  # overwritten.
  def update_segment!(segment, attributes)
    with_lock do
      set_segment_text(segment, attributes[:text]) if attributes.key?(:text)
      set_segment_line_break_after(segment, attributes[:line_break_after]) if attributes.key?(:line_break_after)
      save!
    end
  end

  # Replaces all the segments with ones made from `segment_attributes` (each a {text:, start_ms:, end_ms:,
  # line_break_after:} hash, in order), and saves it, rebuilding text and the doc's body. The new segments are
  # checked as any are (e.g. not overlapping), saving none of them if one fails. Like #update_segment!, reloads
  # and locks itself first.
  def resegment!(segment_attributes)
    new_segments = segment_attributes.map.with_index do |attributes, sort_order|
      Segment.new(**attributes.slice(:text, :start_ms, :end_ms, :line_break_after), sort_order:)
    end
    with_lock do
      replace_segments(new_segments)
      save!
    end
  end

  # Avoid replacing segments when the document is following this transcript.
  def sync_text!(new_text)
    replace_text!(new_text) unless text == new_text
  end

  # Replaces the whole text, merging the segments, if any, into one spanning them all.
  def replace_text!(new_text)
    # An image caption has no segments.
    return update!(text: new_text) unless segments.any?

    replace_segments([
      Segment.new(sort_order: 0, text: new_text, start_ms: segments.first.start_ms, end_ms: segments.last.end_ms)
    ])
    save!
  end

  private

  # Sets whether a line break, rather than a space, follows `segment` in the doc's body. On save, text and the
  # doc's body are rebuilt to follow, and it fails for a segment since replaced, as for #set_segment_text,
  # or one no line break can follow (see #line_break_settable_after?).
  def set_segment_line_break_after(segment, line_break_after)
    current = current_segments.find { it == segment }
    raise ActiveRecord::RecordNotFound, "No segment with id #{segment.id}." unless current
    raise ArgumentError, 'No line break can follow this segment.' unless line_break_settable_after?(current)

    current.line_break_after = line_break_after
  end

  # The segments as they'll be once saved: without those marked for destruction.
  def current_segments
    segments.reject(&:marked_for_destruction?)
  end

  # The last speech segment, searched from the end so each row of the segment list doesn't scan them all.
  # to_a, as the association's reverse_each (Enumerable's) would collect them all first.
  def last_speech_segment
    segments.to_a.reverse_each.find(&:speech?)
  end

  def segments_changing?
    segments.any? { |segment| segment.new_record? || segment.changed? || segment.marked_for_destruction? }
  end

  # An image's caption is set explicitly. Audio and video have segments, even with no speech, to derive it
  # from; with none, it's left nil, which is invalid.
  def default_text_from_segments
    return if text

    self.text = speech_text if segmented?
  end

  def rebuild_text
    self.text = speech_text
  end

  # Inside the save's transaction, so a doc failing to follow rolls the transcript back too: its body, and its
  # AudioSegment blocks, each changed only if it no longer follows. Its denotations are left as they are, even
  # those after an edited segment.
  def sync_doc
    sync_doc_body
    rebuild_segment_blocks
  end

  def sync_doc_body
    doc.update!(body: text) if doc.body != text
  end

  # Rebuilds the AudioSegment blocks in each project that has them on the doc, to span the speech segments as
  # they now are, unless they already do (e.g. as only a line break changed), since the relations and
  # attributes on them go with them.
  def rebuild_segment_blocks
    spans = segment_block_spans

    doc.project_docs.each do |project_doc|
      old_spans = project_doc.block_spans_of(SEGMENT_BLOCK_OBJ)
      next if old_spans.empty? || old_spans == spans

      project_doc.delete_blocks_of(SEGMENT_BLOCK_OBJ)
      project_doc.create_blocks_of(SEGMENT_BLOCK_OBJ, spans)
    end
  end

  # The spans ([begin, end]) of the speech segments in the doc's body, for their AudioSegment blocks.
  def segment_block_spans
    speech_segment_spans.map { it.values_at(:begin, :end) }
  end

  def doc_has_matching_medium
    errors.add(:doc, 'must have the same medium as this transcript') if doc && doc.medium != medium
  end

  # One with no doc is a record of what was transcribed (e.g. a transcription that found no speech), so
  # its segments aren't edited.
  def segments_unchanged_without_doc
    errors.add(:segments, "can't be changed for a transcript with no document") if doc.nil? && segments_changing?
  end

  # The segments, however they're changed (e.g. split or merged), span the same time of the medium as before:
  # from the earliest start to the latest end, as they're chronological. A missing time is reported by the
  # segment's presence check instead.
  def segments_keep_time_span
    return unless segments_changing?

    old_segments = segments.reject(&:new_record?)
    old_span = time_span(old_segments.map(&:start_ms_in_database), old_segments.map(&:end_ms_in_database))
    new_span = time_span(current_segments.map(&:start_ms), current_segments.map(&:end_ms))
    return if old_span.nil? || new_span.nil? || new_span == old_span

    errors.add(:segments, "must span the same time as before, #{old_span.first} to #{old_span.last} ms")
  end

  # From the earliest of `starts` to the latest of `ends`, if there are any.
  def time_span(starts, ends)
    earliest = starts.compact.min
    latest = ends.compact.max
    [earliest, latest] if earliest && latest
  end

  # A doc's transcript can't be left with no speech, since the doc's body follows its speech. One with
  # no doc may (e.g. a transcription that found none, kept as a record).
  def segments_have_speech
    errors.add(:segments, 'must have speech for the transcript of a document') if segments_changing? && speech_segments.empty?
  end
end
