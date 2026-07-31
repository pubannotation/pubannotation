class VideoAudioExtractionService
  def initialize(video_path)
    @video_path = video_path
  end

  def call
    raise ArgumentError, "#{self.class}#call requires a block to receive the extracted audio path." unless block_given?

    Tempfile.create(['extracted_audio', '.wav']) do |tempfile|
      _stdout, stderr, status = Open3.capture3('ffmpeg', '-y', '-i', @video_path, '-vn', '-f', 'wav', tempfile.path)
      raise "Audio extraction failed: #{stderr.strip}" unless status.success?

      yield tempfile.path
    end
  end
end
