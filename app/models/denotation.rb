require 'zip/zip'

class Denotation < ActiveRecord::Base
  ZIP_FILE_PATH = "#{Rails.root}/public/annotations/"
  
  belongs_to :project, :counter_cache => true
  belongs_to :doc, :counter_cache => true

  has_many :modifications, :as => :obj, :dependent => :destroy

  has_many :subrels, :class_name => 'Relation', :as => :subj, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :obj, :dependent => :destroy

  attr_accessible :hid, :begin, :end, :obj

  validates :hid,       :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :obj,       :presence => true
  validates :project_id, :presence => true
  validates :doc_id,    :presence => true

  scope :project_denotations, select(:id).group(:project_id) 
  scope :project_pmcdoc_denotations, lambda{|sourceid|
    joins(:doc).
    where("docs.sourcedb = 'PMC' AND docs.sourceid = ?", sourceid)
  }  
  scope :projects_denotations, lambda {|project_ids|
    where('project_id IN (?)', project_ids)
  }
  scope :within_spans, lambda{|begin_pos, end_pos|
    where(['denotations.begin >= ? AND denotations.end <= ?', begin_pos, end_pos])  
  }

  scope :accessible_projects, lambda{|current_user_id|
      joins([:project, :doc]).
      where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
  }
  
  scope :sql, lambda{|ids|
      where('denotations.id IN(?)', ids).
      order('denotations.id ASC') 
  }
  
  after_save :update_projects_after_save
  before_destroy :update_projects_before_destroy
  
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
  def update_projects_after_save
    project_ids = Array.new
    if self.project.present? 
      project_ids << self.project.id
      if self.project.projects.present?
        # increment projects.denotations_count
        project.projects.each do |project|
          Project.increment_counter(:denotations_count, project.id)
          project_ids << project.id
        end
      end
      # update project annotations_updated_at
      Project.where("projects.id IN (?)", project_ids).update_all(:annotations_updated_at => DateTime.now)
    end
  end
  
  # before destroy
  def update_projects_before_destroy
    project_ids = Array.new
    if self.project.present? 
      project_ids << self.project.id
      if self.project.projects.present?
        project.projects.each do |project|
          # decrement projects_denotations_count
          Project.decrement_counter(:denotations_count, project.id)
          project_ids << project.id
        end
      end
      # update project annotations_updated_at
      Project.where("projects.id IN (?)", project_ids).update_all(:annotations_updated_at => DateTime.now)
    end
  end
  
  def self.sql_find(params, current_user, project)
    if params[:sql].present?
      current_user_id = current_user.present? ? current_user.id : nil
      sanitized_sql = sanitize_sql(params[:sql])
      results = self.connection.execute(sanitized_sql, :includes => [:project])
      if results.present?
        ids = results.collect{|result| result['id']}
        if project.present?
          #results = results.select{|result| result['project_id'] == project.id}
          denotations = self.accessible_projects(current_user_id).projects_denotations([project.id]).sql(ids)
        else
          denotations = self.accessible_projects(current_user_id).sql(ids)
        end
      end       
    end
  end
end
