class TextaeAnnotationsController < ApplicationController
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

    annotation = parse(body)
    textae_annotation = TextaeAnnotation.create!(annotation: annotation)

    render json: {
      message: 'Request was successfully processed. To see the generated textae html, send GET request to result_url.',
      result_url: "#{Rails.application.config.host_url}/textae/#{textae_annotation.uuid}"
    }, status: :created
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
    @annotation = TextaeAnnotation.find_by!(uuid: params[:uuid]).annotation

    render :show, layout: false, status: :ok
  rescue ActiveRecord::RecordNotFound
    render plain: "ERROR: Could not find the annotation with specified ID (#{params[:uuid]})", status: :not_found
  end

  private

  def parse(body)
    case request.content_type
    when 'text/markdown'
      annotation = SimpleInlineTextAnnotation.parse(body)
      JSON.pretty_generate(annotation)
    when 'application/json'
      body
    end
  end

  def render_standard_error(e)
    render json: { error: e.message }, status: :internal_server_error
  end
end
