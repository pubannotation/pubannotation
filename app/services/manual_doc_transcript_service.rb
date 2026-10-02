# Builds a MediaTranscript for a Doc registered by hand with an audio/video Medium, so its detail
# page can highlight and seek it like a transcribed Doc. With no timing to go on, the whole body
# becomes a single segment spanning the media's full duration.
class ManualDocTranscriptService
  # Whether `medium` can get a transcript: audio/video, with a file to measure the duration of.
  def self.applicable?(medium)
    medium&.transcribable? && medium.file.attached?
  end

  # Returns an unsaved MediaTranscript.
  def self.call(medium, body)
    raise ArgumentError, "Specified media can't get a transcript." unless applicable?(medium)

    duration_ms = medium.file.open { |file| (AudioAnalyzer.new(file.path).duration * 1000).round }
    MediaTranscript.new(
      medium:,
      segments: [{ 'text' => body, 'start_ms' => 0, 'end_ms' => duration_ms }]
    )
  end
end
