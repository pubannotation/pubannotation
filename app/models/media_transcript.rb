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

  # `text` is the plain-text Doc body (an image caption, or the resolved speech transcript for
  # audio/video); nullable since populating it is up to the caller/media type. A new record
  # built with segments but no explicit `text` gets one derived below.
  validates :media_transcription_task_id, uniqueness: true, allow_nil: true
  validates :doc_id, uniqueness: true, allow_nil: true
  validate :doc_has_matching_medium
  validate :segments_unchanged_without_doc, on: :update
  validate :segments_have_speech, on: :update, if: :doc

  # Derives `text` from segments for a new record, unless already set explicitly (e.g. an
  # image's caption). Skipped for records loaded from the database.
  after_initialize do
    self.text ||= speech_text if new_record? && segmented?
  end

  # Once created, changed segments (e.g. a segment's text edited) rebuild text, and the doc's body
  # follows it. Checked on every update rather than only as text changes, since normalizing segments can
  # leave text as it was while the body just written differs (e.g. its whitespace alone edited).
  before_update :rebuild_text, if: :segments_changing?
  after_update :sync_doc_body, if: :doc

  # The segments as hashes with 'text', 'start_ms' and 'end_ms', in their order, as #segment_values=
  # takes them.
  def segment_values
    current_segments.map { |segment| { 'text' => segment.text, 'start_ms' => segment.start_ms, 'end_ms' => segment.end_ms } }
  end

  # Replaces the segments with ones made from `values`, each a hash with 'text', 'start_ms' and
  # 'end_ms' (e.g. as AudioTranscriptionService transcribes them), in their order.
  def segment_values=(values)
    segments.each(&:mark_for_destruction)
    values.each_with_index do |value, index|
      segments.build(sort_order: index, text: value['text'], start_ms: value['start_ms'], end_ms: value['end_ms'])
    end
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

  # Replaces the text of the segment at `index` (in sort_order), leaving its start_ms/end_ms as they
  # are. On save, text and the doc's body are rebuilt to follow (see #rebuild_text and #sync_doc_body).
  def set_segment_text(index, new_text)
    segment = current_segments[index] if index >= 0
    raise ArgumentError, "No segment at index #{index}." unless segment

    # Checked once stripped, since strip also removes chars blank? doesn't count as blank, e.g. "\0".
    stripped_text = new_text&.strip
    raise ArgumentError, "Text is missing." if stripped_text.blank?

    segment.text = stripped_text
  end

  # Replaces the whole text, merging the segments, if any, into one spanning them all.
  def replace_text!(new_text)
    return update!(text: new_text) unless segmented?

    first, last = current_segments.values_at(0, -1)
    self.segment_values = [{ 'text' => new_text, 'start_ms' => first.start_ms, 'end_ms' => last.end_ms }]
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
