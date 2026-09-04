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

  # segments is nil for media types that don't produce it (e.g. an image caption), in which case
  # `body` is used as-is. Otherwise the Doc's body is built only from the speech segments, so
  # non-speech labels Whisper may emit (e.g. "(music)") don't leak into the generated text.
  def save_doc(body, segments = nil, media_transcription_task: nil)
    doc_body = segments.present? ? MediaTranscript.new(segments: segments).body : body

    hdoc = Doc.hdoc_normalize!(
      {
        **@attributes,
        username: @user.username,
        body: doc_body,
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

  # For a no_speech result: keeps the segments Whisper produced (e.g. non-speech labels, or none
  # at all) without creating a Doc, since there's no speech worth turning into one.
  def save_transcript(segments, media_transcription_task: nil)
    MediaTranscript.create!(segments:, medium: @medium, media_transcription_task:)
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
