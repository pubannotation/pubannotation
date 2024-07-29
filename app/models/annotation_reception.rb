class AnnotationReception < ApplicationRecord
  belongs_to :annotator
  belongs_to :project

  validates :annotator_id, presence: true
  validates :project_id, presence: true
  validates :uuid, presence: true

  def process_annotation!(annotations_col)
    annotations_col.each do |annotations|
      raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
      AnnotationUtils.normalize!(annotations)
      annotator.annotations_transform!(annotations)
    end

    StoreAnnotationsCollection.new(project, annotations_col, options).call
  end
end
