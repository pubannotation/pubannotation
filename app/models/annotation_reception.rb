class AnnotationReception < ApplicationRecord
  validates :annotator_id, presence: true
  validates :project_id, presence: true
  validates :uuid, presence: true
end
