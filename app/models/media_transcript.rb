class MediaTranscript < ApplicationRecord
  belongs_to :doc

  delegate :medium, to: :doc, allow_nil: true

  # `segments` is an array of timed transcript segments. Each element is a hash with string keys:
  #   'text'     - String, the transcribed text for the segment (may be blank).
  #   'start_ms' - Integer >= 0, offset in milliseconds from the start of the media.
  #   'end_ms'   - Integer >= 0, offset in milliseconds from the start of the media (>= start_ms).
  # The interval is [start_ms, end_ms) (start inclusive, end exclusive). Segments are ordered
  # chronologically and must not overlap: each segment's start_ms must be >= the previous
  # segment's end_ms. Gaps are allowed (e.g. silence between segments), so consecutive segments
  # are not required to touch exactly.
  # An empty array means no speech was detected in the media.
  validates :doc_id, uniqueness: true
  validate :doc_has_medium
  validate :medium_not_image
  validate :segments_are_valid

  private

  def doc_has_medium
    errors.add(:doc, 'must have an associated medium') if doc && medium.nil?
  end

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
