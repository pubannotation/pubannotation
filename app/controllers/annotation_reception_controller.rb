class AnnotationReceptionController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update
    uuid = extract_uuid_from_params
    annotation_reception = AnnotationReception.find_by!(uuid:)
    annotations_col = get_result_from_json_body

    annotation_reception.process_annotation!(annotations_col)

    respond_to do |format|
      format.any {head :no_content}
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.any {head :not_found}
    end

  ensure
    annotation_reception.destroy if annotation_reception.present?
  end

  private

  def get_result_from_json_body
    if request.body.present?
      JSON.parse request.body.read, symbolize_names: true
    end
  end

  def extract_uuid_from_params
    url = params[:_json].first[:callback_url]
    uuid_pattern = %r{([0-9a-fA-F\-]{36})$}

    match = url.match(uuid_pattern)
    match[1] if match
  end
end
