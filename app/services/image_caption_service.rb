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
    # Explicit because the response-parsing below assumes newline-delimited
    # JSON chunks (Ollama's streaming format), not a single JSON object.
    body     = {model: model, messages: messages, stream: true}.to_json

    caption = +''
    Net::HTTP.start(uri.host, uri.port) do |http|
      req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
      req.body = body
      http.request(req) do |res|
        status = res.code.to_i
        raise "Ollama request failed (status #{status})" unless status.between?(200, 299)

        buffer = +''
        res.read_body do |chunk|
          buffer << chunk
          while (newline_index = buffer.index("\n"))
            line = buffer.slice!(0..newline_index).strip
            next if line.empty?

            data = JSON.parse(line)
            caption << data.dig('message', 'content').to_s
          end
        end

        line = buffer.strip
        unless line.empty?
          data = JSON.parse(line)
          caption << data.dig('message', 'content').to_s
        end
      end
    end
    caption.strip
  end
end
