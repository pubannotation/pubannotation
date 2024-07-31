class AnnotationReception < ApplicationRecord
  belongs_to :annotator
  belongs_to :project
  belongs_to :job

  validates :annotator_id, presence: true
  validates :project_id, presence: true

  def process_annotation!(annotations_collection)
    annotations_collection.each do |annotations|
      raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
      AnnotationUtils.normalize!(annotations)
      annotator.annotations_transform!(annotations)
    end

    StoreAnnotationsCollection.new(project, annotations_collection, options).call.join
  end
end
