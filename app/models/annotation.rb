class Annotation < ActiveRecord::Base
  attr_accessible :hid, :subj_id, :subj_type, :pred_id, :obj_id, :obj_type, :type, :doc_id, :begin, :end
  belongs_to :obj

  has_many :annotations_projects
  has_many :projects, through: :annotations_projects

  after_save :increment_projects_annotations_count
  after_destroy :decrement_project_annotations_count

  scope :from_projects, -> (projects) {
    includes(:annotations_projects => :project).
    where('annotations_projects.project_id IN (?)', projects.map{|p| p.id}) if projects.present?
  }
  validates_presence_of :type

  def increment_projects_annotations_count
    if self.projects.present?
      self.projects.each do |project|
        Project.increment_counter(:annotations_count, project.id)
      end
    end
  end

  def decrement_project_annotations_count
    if self.projects.present?
      self.projects.each do |project|
        Project.decrement_counter(:annotations_count, project.id)
      end
    end
  end
end
