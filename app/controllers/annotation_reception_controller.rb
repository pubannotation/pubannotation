class AnnotationReceptionController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update
    annotation_reception = AnnotationReception.find_by!(uuid: params[:uuid])
    annotations_collection = get_result_from_json_body

    annotation_reception.process_annotation!(annotations_collection)

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
end
