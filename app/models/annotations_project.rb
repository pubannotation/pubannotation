class AnnotationsProject < ActiveRecord::Base
  belongs_to :annotation
  belongs_to :project

  attr_accessible :annotation_id, :project_id

  after_destroy :delete_annotation_if_not_belongs_to_project

  def delete_annotation_if_not_belongs_to_project
    annotation.delete if annotation.projects.blank?
  end
end
