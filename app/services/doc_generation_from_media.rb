class DocGenerationFromMedia
  def initialize(project:, medium:, user:, attributes:)
    @project = project
    @medium = medium
    @user = user
    @attributes = attributes
  end

  def generate_transcript
    validate_medium!

    @medium.file.open do |file|
      generate_text(file.path)
    end
  end

  def save_doc(body, segments = nil, media_transcription_task: nil)
    hdoc = Doc.hdoc_normalize!(
      {
        **@attributes,
        username: @user.username,
        body:,
        medium_id: @medium.id
      },
      @user,
      @user.root?
    )

    doc = Doc.store_hdoc!(hdoc)
    @project.add_doc!(doc)
    MediaTranscript.create!(doc:, segments:, medium: @medium, media_transcription_task:) if segments.present?
    doc
  end

  private

  def generate_text(file_path)
    if @medium.image?
      [ImageCaptionService.new(file_path).call, nil]
    elsif @medium.audio?
      result = AudioTranscriptionService.new(file_path).call
      [result[:text], result[:segments]]
    elsif @medium.video?
      result = VideoTranscriptionService.new(file_path).call
      [result[:text], result[:segments]]
    else
      raise ArgumentError, "Unsupported media type: #{@medium.media_type.inspect}"
    end
  end

  def validate_medium!
    raise ArgumentError, "Specified media has no attached file." unless @medium.file.attached?
  end
end
