class Conversions::Inline2jsonController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    source = request.body.read
    result = SimpleInlineTextAnnotation.parse(source)

    render json: result, status: :ok
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
