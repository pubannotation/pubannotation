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

  scope :accessible_projects, lambda{|current_user_id|
    joins(:project).
    where('projects.accessibility = 1 OR projects.user_id = ?', current_user_id)
  }

  scope :sql, lambda{|ids|
      where('relations.id IN(?)', ids).
      order('relations.id ASC') 
  }
    
  after_save :increment_subcatrels_count, :increment_project_relations_count
  
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
  
  def self.sql_find(params, current_user, project)
    if params[:sql].present?
      current_user_id = current_user.present? ? current_user.id : nil
      sanitized_sql = sanitize_sql(params[:sql])
      results = self.connection.execute(sanitized_sql)
      if results.present?
        ids = results.collect{| result | result['id']}
        if project.present?
          # within project
          docs = self.accessible_projects(current_user_id).projects_relations([project.id]).sql(ids)
        else
          # within accessible projects
          docs = self.accessible_projects(current_user_id).sql(ids)
        end
      end     
    end     
  end
  
  # after save
  # def increment_sproject_relations_count
    # if self.project.present? && self.project.sprojects.present?
      # project.sprojects.each do |sproject|
        # Sproject.increment_counter(:relations_count, sproject.id)
      # end
    # end
  # end

  def increment_project_relations_count
    if self.project.present? && self.project.projects.present?
      project.projects.each do |project|
        Project.decrement_counter(:relations_count, project.id)
      end
    end
  end
end
