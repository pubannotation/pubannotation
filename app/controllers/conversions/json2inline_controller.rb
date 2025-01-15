class Conversions::Json2inlineController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    unless request.content_type == 'application/json'
      render plain: "ERROR: Invalid content type. Please set application/json to Content-Type.", status: :unsupported_media_type
      return
    end

    source = JSON.parse(request.body.read)
    result = SimpleInlineTextAnnotation.generate(source)

    render plain: result, status: :ok
  rescue JSON::ParserError => e
    render plain: "ERROR: Invalid JSON. Details: #{e.message}", status: :bad_request
  rescue SimpleInlineTextAnnotation::GeneratorError => e
    render plain: "ERROR: #{e.message}", status: :bad_request
  rescue => e
    render plain: "ERROR: #{e.message}", status: :internal_server_error
  end
end
