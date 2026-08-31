class MediaTranscript < ApplicationRecord
  # `medium` is stored directly (not delegated through doc/media_transcription_task) because
  # both of those associations are deliberately severable without destroying this record — a
  # Doc never exists at all for a no-speech result, and a MediaTranscriptionTask can be cleaned
  # up independently (see the has_one :media_transcript, dependent: :nullify on each). medium_id
  # is the one link this record can't survive losing, so it's the only one that cascades.
  belongs_to :medium
  belongs_to :media_transcription_task, optional: true
  belongs_to :doc, optional: true

  # `segments` is an array of timed transcript segments. Each element is a hash with string keys:
  #   'text'     - String, the transcribed text for the segment (may be blank, or a non-speech
  #                label such as "(music)" — see NonSpeechTextMatcher).
  #   'start_ms' - Integer >= 0, offset in milliseconds from the start of the media.
  #   'end_ms'   - Integer >= 0, offset in milliseconds from the start of the media (>= start_ms).
  # The interval is [start_ms, end_ms) (start inclusive, end exclusive). Segments are ordered
  # chronologically and must not overlap: each segment's start_ms must be >= the previous
  # segment's end_ms. Gaps are allowed (e.g. silence between segments), so consecutive segments
  # are not required to touch exactly.
  # An empty array, or an array containing only non-speech segments, means no speech was
  # detected in the media — see #speech?.
  validates :media_transcription_task_id, uniqueness: true, allow_nil: true
  validates :doc_id, uniqueness: true, allow_nil: true
  validate :medium_not_image
  validate :segments_are_valid

  # The subset of `segments` that are actual speech, excluding Whisper's non-speech labels
  # (e.g. "(music)", "(applause)"). Non-speech segments are kept in `segments` rather than
  # discarded, since the raw transcript may still be useful, but they don't count toward
  # whether the medium contains speech or what the generated Doc's body should be.
  # Guards against segments not matching the documented shape (e.g. nil, or a malformed
  # element) rather than raising, since this can be called before validation runs.
  def speech_segments
    return [] unless segments.is_a?(Array)

    segments.select { |segment| valid_segment?(segment) }
            .reject { |segment| NonSpeechTextMatcher.match?(segment['text']) }
  end

  def speech?
    speech_segments.any?
  end

  def body
    speech_segments.pluck('text').join(' ')
  end

  private

  def medium_not_image
    errors.add(:medium, 'must not be an image') if medium&.image?
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
