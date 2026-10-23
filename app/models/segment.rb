# A timed segment of a MediaTranscript: its text, which may be a non-speech label (see
# NonSpeechTextMatcher), and its interval [start_ms, end_ms), in `position` order within the transcript.
class Segment < ApplicationRecord
  belongs_to :media_transcript

  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  # May be blank, as Whisper can transcribe a segment as nothing (which isn't speech).
  validates :text, exclusion: { in: [nil], message: "can't be nil" }
  validates :start_ms, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :end_ms, numericality: { only_integer: true }, comparison: { greater_than_or_equal_to: :start_ms }

  # Whether it's actual speech, rather than a non-speech label such as "(music)".
  def speech?
    !NonSpeechTextMatcher.match?(text)
  end
end
