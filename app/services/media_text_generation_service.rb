class MediaTextGenerationService
  def initialize(medium, caption_model: nil)
    @medium = medium
    @caption_model = caption_model
  end

  def call
    validate_medium!

    @medium.file.open do |file|
      generate_text(file.path)
    end
  end

  private

  def generate_text(file_path)
    if @medium.image?
      ImageCaptionService.new(file_path, model: @caption_model).call
    elsif @medium.audio?
      segments_to_text(AudioTranscriptionService.new(file_path).call)
    elsif @medium.video?
      segments_to_text(VideoTranscriptionService.new(file_path).call)
    else
      raise ArgumentError, "Unsupported media type: #{@medium.media_type.inspect}"
    end
  end

  # Temporary: will be replaced once MediaTranscript builds this from segments itself.
  def segments_to_text(segments)
    segments.map { |segment| segment['text'] }.join(' ')
  end

  def validate_medium!
    raise ArgumentError, "Specified media has no attached file." unless @medium.file.attached?
  end
end
