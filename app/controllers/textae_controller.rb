class TextaeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create show]

  rescue_from StandardError, with: :render_standard_error

  def create
    unless ['text/markdown', 'application/json'].include?(request.content_type)
      render json: { error: 'Invalid content-type. Please set the correct content-type according to the request.' }, status: :unsupported_media_type
      return
    end

    body = request.body.read
    if body.blank?
      render json: { error: 'Request body cannot be empty.' }, status: :bad_request
      return
    end

    annotation = parse_request_body(body)
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
    textae_annotation = TextaeAnnotation.find_by!(uuid: params[:uuid])
    textae_html = TextaeAnnotation.generate_textae_html(textae_annotation.annotation)

    render plain: textae_html, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    render json: { error: e.message }, status: :not_found
  end

  private

  def parse_request_body(body)
    if request.content_type == 'text/markdown'
      annotation = SimpleInlineTextAnnotation.parse(body)
      JSON.pretty_generate(annotation)
    elsif request.content_type == 'application/json'
      body
    end
  end

  def render_standard_error(e)
    render json: { error: e.message }, status: :internal_server_error
  end
end
