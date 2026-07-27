class DocGenerationFromMedia
  def initialize(project:, medium:, user:, attributes:)
    @project = project
    @medium = medium
    @user = user
    @attributes = attributes
  end

  def call
    validate_medium!

    body = @medium.file.open do |file|
      generate_text(file.path)
    end

    hdoc = Doc.hdoc_normalize!(
      {
        **@attributes,
        username: @user.username,
        body: body,
        medium_id: @medium.id
      },
      @user,
      @user.root?
    )

    doc = Doc.store_hdoc!(hdoc)
    @project.add_doc!(doc)
    doc
  end

  private

  def generate_text(file_path)
    if @medium.image?
      ImageCaptionService.new(file_path).call
    else
      AudioTranscriptionService.new(file_path).call
    end
  end

  def validate_medium!
    raise ArgumentError, "Text generation is supported only for image or audio media." unless @medium.image? || @medium.audio?
    raise ArgumentError, "Specified media has no attached file." unless @medium.file.attached?
  end
end
