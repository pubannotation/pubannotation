class Annotation < ActiveRecord::Base
  attr_accessible :hid, :subj_id, :subj_type, :pred_id, :obj_id, :obj_type, :type, :doc_id, :begin, :end, :pred
  belongs_to :obj
  belongs_to :subj
  belongs_to :pred

  has_many :annotations_projects
  has_many :projects, through: :annotations_projects

  after_save :increment_projects_annotations_count
  after_destroy :decrement_project_annotations_count

  scope :from_projects, -> (projects) {
    includes(:annotations_projects => :project).
    where('annotations_projects.project_id IN (?)', projects.map{|p| p.id}) if projects.present?
  }
  validates_presence_of :type
  validates :obj_id, numericality: true, allow_nil: true
  validates :subj_id, numericality: true, allow_nil: true
  validates :doc_id, numericality: true, allow_nil: true
  validates :pred_id, numericality: true, allow_nil: true
  validates :begin, numericality: true, allow_nil: true
  validates :end, numericality: true, allow_nil: true

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

  def self.insert_test_data
    limit(1000).each do |a|
      annotations_project = a.annotations_projects.build(project_id: 1)
      if annotations_project.valid?
        annotations_project.save
      end
    end
  end
end
