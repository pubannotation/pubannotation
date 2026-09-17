class MediaTextGenerationService
  def initialize(medium, caption_model: nil)
    @medium = medium
    @caption_model = caption_model
  end

  # Returns an unsaved MediaTranscript. Its text is the caption as-is for an image, or the
  # speech-only text (excluding Whisper's non-speech labels) for audio/video.
  def call
    validate_medium!

    @medium.file.open do |file|
      build_media_transcript(file.path)
    end
  end

  private

  def build_media_transcript(file_path)
    case @medium.media_type
    when 'image'
      MediaTranscript.new(medium: @medium, text: ImageCaptionService.new(file_path, model: @caption_model).call)
    when 'audio'
      MediaTranscript.new(medium: @medium, segments: AudioTranscriptionService.new(file_path).call)
    when 'video'
      MediaTranscript.new(medium: @medium, segments: VideoTranscriptionService.new(file_path).call)
    else
      raise ArgumentError, "Unsupported media type: #{@medium.media_type.inspect}"
    end
  end

  def validate_medium!
    raise ArgumentError, "Specified media has no attached file." unless @medium.file.attached?
  end
end
