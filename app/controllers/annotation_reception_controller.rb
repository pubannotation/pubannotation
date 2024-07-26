class AnnotationReceptionController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update
    uuid = extract_uuid_from_params
    annotation_reception = AnnotationReception.find_by(uuid:)
    annotator = Annotator.find(annotation_reception.annotator_id)
    project = Project.find(annotation_reception.project_id)
    options = annotation_reception.options

    result = get_result_from_json_body
    annotations_col = (result.class == Array) ? result : [result]

    annotations_col.each_with_index do |annotations, i|
      raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
      AnnotationUtils.normalize!(annotations)
      annotator.annotations_transform!(annotations)
    end

    StoreAnnotationsCollection.new(project, annotations_col, options).call.join

    respond_to do |format|
      format.any {head :no_content}
    end
  end

  private

  def get_result_from_json_body
    if request.body.present?
      JSON.parse request.body.read, symbolize_names: true
    end
  end

  def extract_uuid_from_params
    url = params[:callback_url]
    uuid_pattern = %r{([0-9a-fA-F\-]{36})$}

    match = url.match(uuid_pattern)
    match[1] if match
  end
end
