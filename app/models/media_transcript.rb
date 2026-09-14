class MediaTranscript < ApplicationRecord
  # `medium` is stored directly (not delegated through doc/media_transcription_task) since both
  # of those associations are optional here: a Doc never exists at all for a no-speech result,
  # and a MediaTranscriptionTask can be cleaned up independently of this record (see the
  # has_one :media_transcript, dependent: :nullify on MediaTranscriptionTask). A Doc, once it
  # does exist for this record, is not severable the same way — Doc has_one :media_transcript,
  # dependent: :destroy, so deleting the Doc that was generated from this transcript takes the
  # transcript with it.
  belongs_to :medium
  belongs_to :media_transcription_task, optional: true
  belongs_to :doc, optional: true

  # `text` is the plain-text body for this transcript (e.g. an image caption, or the
  # already-resolved speech transcript for audio/video), used as the generated Doc's body.
  # It's nullable rather than required: which media types populate it, and how, is up to the
  # caller that creates this record, not a universal invariant this model enforces.
  #
  # `segments` is an array of timed transcript segments. Each element is a hash with string keys:
  #   'text'     - String, the transcribed text for the segment (may be blank, or a non-speech
  #                label such as "(music)" — see NonSpeechTextMatcher).
  #   'start_ms' - Integer >= 0, offset in milliseconds from the start of the media.
  #   'end_ms'   - Integer >= 0, offset in milliseconds from the start of the media (>= start_ms).
  # The interval is [start_ms, end_ms) (start inclusive, end exclusive). Segments are ordered
  # chronologically and must not overlap: each segment's start_ms must be >= the previous
  # segment's end_ms. Gaps are allowed (e.g. silence between segments), so consecutive segments
  # are not required to touch exactly. Media types that don't produce segments (e.g. images)
  # simply leave this at its default empty array.
  # An empty array, or an array containing only non-speech segments, means no speech was
  # detected in the media (`text` ends up blank in that case too — see #speech?).
  validates :media_transcription_task_id, uniqueness: true, allow_nil: true
  validates :doc_id, uniqueness: true, allow_nil: true
  validate :doc_has_matching_medium
  validate :segments_are_valid

  # The subset of `segments` that are actual speech, excluding Whisper's non-speech labels
  # (e.g. "(music)", "(applause)"). Non-speech segments are kept in `segments` rather than
  # discarded, since the raw transcript may still be useful, but they don't count toward
  # whether the medium contains speech or what the generated Doc's body should be. Assumes
  # segments is already an Array, as segments_are_valid requires — not meant to be called on
  # an instance that hasn't been validated (e.g. persisted, or built via create!) yet.
  def speech_segments
    segments.select { |segment| valid_segment?(segment) }
            .reject { |segment| NonSpeechTextMatcher.match?(segment['text']) }
  end

  # Whether this transcript has any real content to show, for either media type: a non-blank
  # caption for an image, or actual speech (as opposed to silence, or only non-speech labels
  # like "(music)") for audio/video. Checking `text` rather than `segments` directly is what
  # lets this apply to images too, which never have segments to check in the first place.
  def speech?
    text.present?
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
