class TextaeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create show]

  def create
    unless ['text/markdown', 'application/json'].include?(request.content_type)
      render json: { error: 'Invalid content-type. Please set the correct content-type according to the request.' }, status: :unsupported_media_type
      return
    end

    annotation = parse_request_body
    textae_annotation = TextaeAnnotation.create!(annotation: annotation)

    TextaeAnnotation.older_than_one_day.destroy_all

    render json: {
      message: 'Request was successfully processed. To see the generated textae html, send GET request to result_url.',
      result_url: "#{Rails.application.config.host_url}/textae/#{textae_annotation.uuid}"
    }, status: :created
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
  end

  private

  def parse_request_body
    body = request.body.read

    if request.content_type == 'text/markdown'
      annotation = SimpleInlineTextAnnotation.parse(body)
      JSON.pretty_generate(annotation)
    elsif request.content_type == 'application/json'
      body
    end
  end
end
