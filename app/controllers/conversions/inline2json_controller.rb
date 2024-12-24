class Conversions::Inline2jsonController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  MAX_PAYLOAD_SIZE = 10.megabytes

  def create
    if request.content_length >= MAX_PAYLOAD_SIZE
      render json: { error: 'Payload too large. The size should be less than 10 MB.' }, status: :payload_too_large
      return
    end

    source = request.body.read
    result = SimpleInlineTextAnnotation.parse(source)

    render json: result, status: :ok
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
