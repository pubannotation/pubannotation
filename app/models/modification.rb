class Modification < ActiveRecord::Base
  belongs_to :project
  belongs_to :obj, :polymorphic => true

  attr_accessible :hid, :pred, :obj, :project_id

  validates :hid, :presence => true
  validates :pred, :presence => true
  validates :obj, :presence => true

  after_save :increment_project_modifications_num, :update_project_updated_at
  after_destroy :decrement_project_modifications_num, :update_project_updated_at

  def span
    obj.span
  end

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

  def update_project_updated_at
    self.project.update_updated_at
  end

  def increment_project_modifications_num
    Project.increment_counter(:modifications_num, self.project.id)
  end

  def decrement_project_modifications_num
    Project.decrement_counter(:modifications_num, self.project.id)
  end

end
