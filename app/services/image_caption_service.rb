class ImageCaptionService
  OLLAMA_HOST = ENV.fetch('OLLAMA_HOST', 'http://localhost:11434')
  OLLAMA_MODEL = ENV.fetch('OLLAMA_CAPTION_MODEL', 'moondream')
  PROMPT = 'Describe the content of this image concisely.'

  def initialize(image_path)
    @image_path = image_path
  end

  def call
    llm = LLM.ollama(key: nil, host: OLLAMA_HOST)
    agent = LLM::Agent.new(llm, model: OLLAMA_MODEL)
    response = agent.ask(PROMPT, with: @image_path)
    response.content
  end
end
