require 'zip/zip'

class Denotation < ActiveRecord::Base
  include DenotationsHelper
  
  belongs_to :project
  belongs_to :doc, :counter_cache => true

  has_many :modifications, :as => :obj, :dependent => :destroy

  has_many :subrels, :class_name => 'Relation', :as => :subj, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :obj, :dependent => :destroy

  attr_accessible :hid, :begin, :end, :obj, :project_id, :doc_id

  validates :hid,       :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :obj,       :presence => true
  validates :project_id, :presence => true
  validates :doc_id,    :presence => true

  scope :from_projects, -> (projects) {
    where('project_id IN (?)', projects.map{|p| p.id}) if projects.present?
  }

  scope :within_span, -> (span) {
    where('denotations.begin >= ? AND denotations.end <= ?', span[:begin], span[:end]) if span.present?
  }

  scope :accessible_projects, lambda{|current_user_id|
    joins([:project, :doc]).
    where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
  }
  
  scope :sql, lambda{|ids|
    where('denotations.id IN(?)', ids).
    order('denotations.id ASC') 
  }
  
  after_save :increment_project_denotations_num, :update_project_updated_at
  after_destroy :decrement_project_denotations_num, :update_project_updated_at
  
  def get_hash
    hdenotation = Hash.new
    hdenotation[:id]   = hid
    hdenotation[:span] = {:begin => self.begin, :end => self.end}
    hdenotation[:obj]  = obj
    hdenotation
  end

  # after save
  def update_project_updated_at
    self.project.update_updated_at
  end

  def increment_project_denotations_num
    self.project.increment!(:denotations_num)
  end

  def decrement_project_denotations_num
    self.project.decrement!(:denotations_num)
  end
  
  def self.sql_find(params, current_user, project)
    if params[:sql].present?
      current_user_id = current_user.present? ? current_user.id : nil
      sanitized_sql = sanitize_sql(params[:sql])
      results = self.connection.execute(sanitized_sql, :includes => [:project])
      if results.present?
        ids = results.collect{|result| result['id']}
        denotations = self.accessible_projects(current_user_id).from_projects([project]).sql(ids)
      end       
    end
  end
end
