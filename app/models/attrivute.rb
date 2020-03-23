class Attrivute < ActiveRecord::Base
  # The name of the class is changed to avoid conflict with the reserved word 'attribute'
  belongs_to :project
  belongs_to :subj, polymorphic: true

  attr_accessible :hid, :project_id, :subj, :obj, :pred

  validates :hid, presence: true
  validates :subj, presence: true
  validates :obj, presence: true
  validates :pred, presence: true

  after_save :update_project_updated_at
  after_destroy :update_project_updated_at

  def span
    subj.span
  end

  def get_hash
    {
      id:   hid,
      subj: subj.hid,
      obj:  obj,
      pred: pred
    }
  end

  scope :from_projects, -> (projects) {
    where('attrivutes.project_id IN (?)', projects.map{|p| p.id}) if projects.present?
  }

  def update_project_updated_at
    self.project.update_updated_at
  end

  def self.new_id
    'A' + rand(99999).to_s
  end

end
