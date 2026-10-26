# A timed segment of a MediaTranscript: its text, which may be a non-speech label (see
# NonSpeechTextMatcher), and its interval [start_ms, end_ms), in `sort_order` within the transcript.
class Segment < ApplicationRecord
  belongs_to :media_transcript

  # Line breaks, tabs and runs of spaces as one space, and none around the text.
  normalizes :text, with: ->(text) { text.gsub(/\r\n|[\r\n\t]/, ' ').gsub(/ {2,}/, ' ').strip }

  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # May be blank, as Whisper can transcribe a segment as nothing (which isn't speech).
  validates :text, exclusion: { in: [nil], message: "can't be nil" }
  # Each checked further only once present, so a missing one is reported just as blank.
  validates :start_ms, :end_ms, presence: true
  validates :start_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :end_ms, numericality: { only_integer: true, allow_nil: true }
  validates :end_ms, comparison: { greater_than_or_equal_to: :start_ms, allow_nil: true }, if: :start_ms

  # Whether it's actual speech, rather than a non-speech label such as "(music)".
  def speech?
    !NonSpeechTextMatcher.match?(text)
  end
end
