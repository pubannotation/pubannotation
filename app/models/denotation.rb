class Denotation < ActiveRecord::Base
  belongs_to :project, :counter_cache => true
  belongs_to :doc, :counter_cache => true

  has_many :instances, :foreign_key => "obj_id", :dependent => :destroy

  has_many :subrels, :class_name => 'Relation', :as => :subj, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :obj, :dependent => :destroy

  has_many :insmods, :class_name => 'Modification', :through => :instances, :source => :modifications


  attr_accessible :hid, :begin, :end, :obj

  validates :hid,       :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :obj,  :presence => true
  validates :project_id, :presence => true
  validates :doc_id,    :presence => true

  scope :project_denotations, select(:id).group(:project_id)
  scope :projects_denotations, lambda {|project_ids|
    where('project_id IN (?)', project_ids)
  }
  scope :within_spans, lambda{|begin_pos, end_pos|
    where(['denotations.begin >= ? AND denotations.end < ?', begin_pos, end_pos])  
  }
  
  after_save :increment_sproject_denotations_count
  before_destroy :decrement_sproject_denotations_count
  
  def get_hash
    hdenotation = Hash.new
    hdenotation[:id]       = hid
    hdenotation[:span]     = {:begin => self.begin, :end => self.end}
    hdenotation[:obj] = obj
    hdenotation
  end

  # returns denotations count which belongs to project and doc
  def self.project_denotations_count(project_id, denotations)
    denotations.project_denotations.count[project_id].to_i  
  end  
  
  # after save
  def increment_sproject_denotations_count
    if self.project.present? && self.project.sprojects.present?
      project.sprojects.each do |sproject|
        Sproject.increment_counter(:denotations_count, sproject.id)
      end
    end
  end
  
  # before destroy
  def decrement_sproject_denotations_count
    if self.project.present? && self.project.sprojects.present?
      project.sprojects.each do |sproject|
        Sproject.decrement_counter(:denotations_count, sproject.id)
      end
    end
  end
end
