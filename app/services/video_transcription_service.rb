class VideoTranscriptionService
  def initialize(video_path)
    @video_path = video_path
  end

  def call
    Tempfile.create(['extracted_audio', '.wav']) do |tempfile|
      VideoAudioExtractor.new(@video_path).extract_to(tempfile.path)
      AudioTranscriptionService.new(tempfile.path).call
    end
  end
end
