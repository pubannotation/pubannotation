class AnnotationReception < ApplicationRecord
  validates :annotator_id, presence: true
  validates :project_id, presence: true
  validates :uuid, presence: true

  def process_annotation!(annotations_col, annotator, project, options)
    annotations_col.each do |annotations|
      raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
      AnnotationUtils.normalize!(annotations)
      annotator.annotations_transform!(annotations)
    end

    StoreAnnotationsCollection.new(project, annotations_col, options).call.join
  end
end
