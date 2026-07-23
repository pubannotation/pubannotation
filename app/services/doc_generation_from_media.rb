class DocGenerationFromMedia
  def initialize(project:, medium:, user:, attributes:)
    @project = project
    @medium = medium
    @user = user
    @attributes = attributes
  end

  def call
    validate_medium!

    caption = @medium.file.open do |file|
      ImageCaptionService.new(file.path).call
    end

    hdoc = Doc.hdoc_normalize!(
      {
        **@attributes,
        username: @user.username,
        body: caption,
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

  def validate_medium!
    raise ArgumentError, "Text generation is supported only for image media." unless @medium.image?
    raise ArgumentError, "Specified media has no attached file." unless @medium.file.attached?
  end
end
