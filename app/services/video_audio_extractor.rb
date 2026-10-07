# Extracts WAV audio to a caller-owned file.
class VideoAudioExtractor
  class ExtractionError < StandardError; end

  def initialize(video_path)
    @video_path = video_path
  end

  def extract_to(output_path)
    _stdout, stderr, status = Open3.capture3('ffmpeg', '-y', '-i', @video_path, '-vn', '-f', 'wav', output_path)
    raise ExtractionError, "Audio extraction failed: #{stderr.strip}" unless status.success?

    output_path
  end
end
