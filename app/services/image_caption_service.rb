class ImageCaptionService
  OLLAMA_HOST = ENV.fetch('OLLAMA_HOST', 'localhost')
  OLLAMA_MODEL = ENV.fetch('OLLAMA_CAPTION_MODEL', 'moondream')
  PROMPT = 'Describe the content of this image concisely.'

  def initialize(image_path)
    @image_path = image_path
  end

  def call
    llm = LLM.ollama(key: nil, host: OLLAMA_HOST)
    ctx = LLM::Context.new(llm, model: OLLAMA_MODEL)
    response = ctx.talk([PROMPT, ctx.local_file(@image_path)])
    response.content
  end
end
