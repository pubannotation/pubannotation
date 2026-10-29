# A timed segment of a MediaTranscript: its text, which may be a non-speech label (see
# NonSpeechTextMatcher), and its interval [start_ms, end_ms), in `sort_order` within the transcript.
class Segment < ApplicationRecord
  belongs_to :media_transcript, inverse_of: :segments

  normalizes :text, with: ->(text) { TextNormalizable.normalize_inline_text(text) }

  # May be blank, as Whisper can transcribe a segment as nothing (which isn't speech).
  validates :text, exclusion: { in: [nil], message: "can't be nil" }
  # Each checked further only once present, so a missing one is reported just as blank.
  validates :sort_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :start_ms, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :end_ms, presence: true, numericality: { only_integer: true, allow_nil: true },
                     comparison: { greater_than_or_equal_to: :start_ms, allow_nil: true, if: :start_ms }
  validate :start_not_before_previous_end

  # Whether it's actual speech, rather than a non-speech label such as "(music)".
  def speech?
    !NonSpeechTextMatcher.match?(text)
  end

  private

  # Against the segment before it in its transcript, so the segments don't overlap.
  def start_not_before_previous_end
    previous = previous_segment
    return unless previous && start_ms < previous.end_ms

    errors.add(:start_ms, "must be greater than or equal to the previous segment's end_ms (#{previous.end_ms})")
  end

  # The one just before it in sort_order among the other segments of its transcript staying once saved, or
  # nil for the first.
  def previous_segment
    media_transcript.segments
      .reject { |other| other.equal?(self) || other.marked_for_destruction? }
      .select { |other| other.sort_order < sort_order }
      .max_by(&:sort_order)
  end
end
