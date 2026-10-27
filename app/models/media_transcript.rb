class MediaTranscript < ApplicationRecord
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

  # Records loaded from the database already have their text.
  after_initialize :default_text_from_segments, if: :new_record?

  # Once created, changed segments (e.g. a segment's text edited) rebuild text, and the doc's body
  # follows it.
  before_update :rebuild_text, if: :segments_changing?
  after_update :sync_doc_body, if: -> { doc && saved_change_to_text? }

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

  def speech_text
    speech_segments.map(&:text).join(' ')
  end

  # Each speech segment's char offset ({begin:, end:}) into what #speech_text builds from them (a
  # single space between consecutive speech segments, regardless of non-speech segments between
  # them in `segments`), in the same order as #speech_segments, paired with its start_ms.
  def speech_segment_spans
    char_position = 0

    speech_segments.map do |segment|
      char_begin = char_position
      char_end = char_begin + segment.text.length
      char_position = char_end + 1

      { begin: char_begin, end: char_end, start_ms: segment.start_ms }
    end
  end

  # generation_model as AudioTranscriptionService.generation_model records it, e.g. "whisper:ggml-base.en".
  def transcribed_by_whisper?
    generation_model.to_s.start_with?('whisper:')
  end

  # Replaces the text of the segment with `id`, leaving its start_ms/end_ms as they are. On save, text and
  # the doc's body are rebuilt to follow (see #rebuild_text and #sync_doc_body). Fails for a segment since
  # replaced, e.g. by #replace_segments, which gives the new ones new ids.
  def set_segment_text(id, new_text)
    segment = current_segments.find { |current| current.id == id }
    raise ArgumentError, "No segment with id #{id}." unless segment

    # Checked once stripped, since strip also removes chars blank? doesn't count as blank, e.g. "\0".
    stripped_text = new_text&.strip
    raise ArgumentError, "Text is missing." if stripped_text.blank?

    segment.text = stripped_text
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

  # The segments as they'll be once saved: without those marked for destruction.
  def current_segments
    segments.reject(&:marked_for_destruction?)
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

  # Inside the save's transaction, so a doc failing to save rolls the transcript back too. Its
  # denotations are left as they are, even those after an edited segment.
  def sync_doc_body
    doc.update!(body: text) if doc.body != text
  end

  def doc_has_matching_medium
    errors.add(:doc, 'must have the same medium as this transcript') if doc && doc.medium != medium
  end

  # One with no doc is a record of what was transcribed (e.g. a transcription that found no speech), so
  # its segments aren't edited.
  def segments_unchanged_without_doc
    errors.add(:segments, "can't be changed for a transcript with no document") if doc.nil? && segments_changing?
  end

  # A doc's transcript can't be left with no speech, since the doc's body follows its speech. One with
  # no doc may (e.g. a transcription that found none, kept as a record).
  def segments_have_speech
    errors.add(:segments, 'must have speech for the transcript of a document') if segments_changing? && speech_segments.empty?
  end
end
