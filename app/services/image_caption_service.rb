class ImageCaptionService
  PROMPT = 'Describe the content of this image concisely.'

  def initialize(image_path)
    @image_path = image_path
  end

  def call
    host  = ENV.fetch('OLLAMA_HOST', 'localhost')
    model = ENV.fetch('OLLAMA_CAPTION_MODEL', 'moondream')
    image_data = Base64.strict_encode64(File.binread(@image_path))
    uri      = URI("http://#{host}:11434/api/chat")
    # Single-message format (content+images together) makes moondream return
    # a single unrelated word (e.g. "urn") instead of a caption — confirmed
    # by manual testing. Splitting into two messages avoids that.
    messages = [
      {role: 'user', content: PROMPT},
      {role: 'user', content: '', images: [image_data]}
    ]
    body     = {model: model, messages: messages}.to_json

    caption = +''
    Net::HTTP.start(uri.host, uri.port) do |http|
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = body
      http.request(req) do |res|
        res.read_body do |chunk|
          chunk.each_line do |line|
            data = JSON.parse(line) rescue next
            caption << data.dig('message', 'content').to_s
          end
        end
      end
    end
    caption.strip
  end
end
