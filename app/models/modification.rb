class Modification < ActiveRecord::Base
  belongs_to :project
  belongs_to :obj, :polymorphic => true

  attr_accessible :hid, :pred

  validates :hid, :presence => true
  validates :pred, :presence => true
  validates :obj, :presence => true

  after_save :increment_project_annotations_count, :update_project_updated_at
  after_destroy :decrement_project_annotations_count, :update_project_updated_at

  def get_hash
    hmodification = Hash.new
    hmodification[:id] = hid
    hmodification[:pred] = pred
    hmodification[:obj] = obj.hid
    hmodification
  end

  scope :from_projects, -> (projects) {
    where('modifications.project_id IN (?)', projects.map{|p| p.id}) if projects.present?
  }

  def increment_project_annotations_count
    Project.increment_counter(:annotations_count, project.id) if self.project.present?
  end

  def update_project_updated_at
    project.update_attribute(:updated_at, DateTime.now) if self.project.present?
  end

  def decrement_project_annotations_count
    Project.decrement_counter(:annotations_count, project.id) if self.project.present?
  end
end
