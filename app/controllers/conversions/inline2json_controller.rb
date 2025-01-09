class Conversions::Inline2jsonController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  MAX_PAYLOAD_SIZE = 10.megabytes

  def create
    unless request.content_type == 'text/plain' || request.content_type == 'text/markdown'
      render plain: "ERROR: Invalid content type. Please set text/plain or text/markdown to Content-Type.", status: :unsupported_media_type
      return
    end

    if request.content_length >= MAX_PAYLOAD_SIZE
      render plain: "ERROR: Payload too large. The size should be less than 10 MB.", status: :payload_too_large
      return
    end

    source = request.body.read
    result = SimpleInlineTextAnnotation.parse(source)

    render json: result, status: :ok
  rescue => e
    render plain: "ERROR: #{e.message}", status: :internal_server_error
  end
end
