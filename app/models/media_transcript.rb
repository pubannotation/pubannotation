class MediaTranscript < ApplicationRecord
  # `medium` is stored directly (not via doc/media_transcription_task) since both associations
  # are optional: a Doc never exists for a no-speech result, and MediaTranscriptionTask can be
  # cleaned up independently (dependent: :nullify). A Doc, once linked, is not severable the
  # same way (Doc has_one :media_transcript, dependent: :destroy).
  belongs_to :medium
  belongs_to :media_transcription_task, optional: true
  belongs_to :doc, optional: true

  # `text` is the plain-text Doc body (an image caption, or the resolved speech transcript for
  # audio/video); nullable since populating it is up to the caller/media type. A new record
  # built with `segments` but no explicit `text` gets one derived below.
  #
  # `segments` is an array of timed transcript segments, each a hash with 'text' (String, may
  # be a non-speech label — see NonSpeechTextMatcher), 'start_ms', and 'end_ms' (non-negative
  # Integers, start <= end, interval [start_ms, end_ms)). Segments must be chronological and
  # non-overlapping (enforced below); images leave this at its default empty array.
  validates :media_transcription_task_id, uniqueness: true, allow_nil: true
  validates :doc_id, uniqueness: true, allow_nil: true
  validate :doc_has_matching_medium
  validate :segments_are_valid

  # Derives `text` from segments for a new record, unless already set explicitly (e.g. an
  # image's caption). Skipped for records loaded from the database.
  after_initialize do
    self.text ||= speech_text if new_record? && segments.present?
  end

  # Segments that are actual speech, excluding Whisper's non-speech labels (e.g. "(music)").
  # Kept rather than discarded in `segments`, since the raw transcript may still be useful.
  def speech_segments
    segments.select { |segment| valid_segment?(segment) }
            .reject { |segment| NonSpeechTextMatcher.match?(segment['text']) }
  end

  def speech_text
    speech_segments.pluck('text').join(' ')
  end

  private

  def doc_has_matching_medium
    errors.add(:doc, 'must have the same medium as this transcript') if doc && doc.medium != medium
  end

  def segments_are_valid
    return errors.add(:segments, 'must be an array') unless segments.is_a?(Array)

    previous_end_ms = nil

    segments.each_with_index do |segment, index|
      unless valid_segment?(segment)
        errors.add(:segments, "at index #{index} must be a hash with a 'text' string and non-negative integer " \
                               "'start_ms'/'end_ms' where start_ms <= end_ms")
        next
      end

      errors.add(:segments, "at index #{index} overlaps the previous segment: start_ms must be >= the previous end_ms") if
        previous_end_ms && segment['start_ms'] < previous_end_ms

      previous_end_ms = segment['end_ms']
    end
  end

  def valid_segment?(segment)
    segment.is_a?(Hash) &&
      segment['text'].is_a?(String) &&
      segment['start_ms'].is_a?(Integer) && segment['start_ms'] >= 0 &&
      segment['end_ms'].is_a?(Integer) && segment['end_ms'] >= segment['start_ms']
  end
end
