class Relation < ActiveRecord::Base
  belongs_to :project, :counter_cache => true
  belongs_to :subj, :polymorphic => true
  belongs_to :obj, :polymorphic => true

  has_many :modifications, :as => :obj, :dependent => :destroy

  attr_accessible :hid, :pred

  validates :hid,     :presence => true
  validates :pred,    :presence => true
  validates :subj_id, :presence => true
  validates :obj_id,  :presence => true
  validate :validate

  scope :project_relations, select(:id).group("relations.project_id")
  scope :projects_relations, lambda{|project_ids|
    where('project_id IN (?)', project_ids)
  }
  
  after_save :increment_subcatrels_count, :increment_sproject_relations_count
  
  def get_hash
    hrelation = Hash.new
    hrelation[:id]   = hid
    hrelation[:pred] = pred
    hrelation[:subj] = subj.hid
    hrelation[:obj]  = obj.hid
    hrelation
  end
  
  def validate
    if obj.class == Block  || subj.class == Block
      if subj.class != Block
        errors.add(:subj_type, 'subj should be a Block when obj is a Block')
      elsif obj.class != Block
        errors.add(:obj_type, 'obj should be a Block when subj is a Block')
      end
    end
  end
  
  def self.project_relations_count(project_id, relations)
    relations.project_relations.count[project_id].to_i
  end
  
  def increment_subcatrels_count
    if self.subj_type == 'Denotation'
      Doc.increment_counter(:subcatrels_count, subj.doc_id)
    end
  end
  
  # after save
  def increment_sproject_relations_count
    if self.project.present? && self.project.sprojects.present?
      project.sprojects.each do |sproject|
        Sproject.increment_counter(:relations_count, sproject.id)
      end
    end
  end
end
