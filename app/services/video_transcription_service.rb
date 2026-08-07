class VideoTranscriptionService
  def initialize(video_path)
    @video_path = video_path
  end

  def call
    Tempfile.create(['extracted_audio', '.wav']) do |tempfile|
      extract_audio(tempfile.path)
      AudioTranscriptionService.new(tempfile.path).call
    end
  end

  private

  def extract_audio(output_path)
    _stdout, stderr, status = Open3.capture3('ffmpeg', '-y', '-i', @video_path, '-vn', '-f', 'wav', output_path)
    raise "Audio extraction failed: #{stderr.strip}" unless status.success?
  end
end
