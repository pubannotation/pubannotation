class Sproject < Project
  belongs_to :user
  has_many :projects_sprojects
  has_and_belongs_to_many :projects, :after_add => :increment_counters, :after_remove => :decrement_counters
  before_destroy { projects.clear }
  attr_accessible :name, :description, :author, :license, :status, :accessibility, :reference, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter
  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}
  
  scope :accessible, lambda{|current_user|
    if current_user.present?
      where('accessibility = ? OR user_id =?', 1, current_user.id)
    else
      where(:accessibility => 1)
    end
  }
  scope :order_pmdocs_count, 
    joins("
      LEFT OUTER JOIN projects_sprojects ON projects_sprojects.sproject_id = projects.id
      LEFT OUTER JOIN docs_projects ON docs_projects.project_id IN (projects_sprojects.project_id) 
      LEFT OUTER JOIN docs ON docs.id = docs_projects.doc_id AND docs.sourcedb = 'PubMed'
    ").group('projects.id').order("count(docs.id) DESC")

  scope :order_pmcdocs_count, 
    joins("
      LEFT OUTER JOIN projects_sprojects ON projects_sprojects.sproject_id = projects.id
      LEFT OUTER JOIN docs_projects ON docs_projects.project_id IN (projects_sprojects.project_id) 
      LEFT OUTER JOIN docs ON docs.id = docs_projects.doc_id AND docs.sourcedb = 'PMC'
    ").
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_denotations_count, 
    joins('
      LEFT OUTER JOIN projects_sprojects ON projects_sprojects.sproject_id = projects.id
      LEFT OUTER JOIN denotations ON denotations.project_id IN (projects_sprojects.project_id)').
    group('projects.id').
    order("count(denotations.id) DESC")
    
  scope :order_relations_count,
    joins('
      LEFT OUTER JOIN projects_sprojects ON projects_sprojects.sproject_id = projects.id
      LEFT OUTER JOIN relations ON relations.project_id IN (projects_sprojects.project_id)').
    group('projects.id').
    order('count(relations.id) DESC')   
     
  def self.order_by(sprojects, order, current_user)
    case order
    when 'pmdocs_count', 'pmcdocs_count', 'denotations_count', 'relations_count'
      sprojects.accessible(current_user).order("#{order} DESC")
    else
      sprojects.accessible(current_user).order('name ASC')
    end    
  end
        
  def pmdocs
    Doc.pmdocs.projects_docs(project_ids)
  end

  def pmcdocs
    Doc.pmcdocs.projects_docs(project_ids)
  end
  
  def project_ids
    projects.present? ? projects.collect{|project| project.id} : [0]
  end
  
  def accessible?(current_user)
    self.accessibility == 1 || (current_user.present? && self.user == current_user)
  end
  
  def get_divs(sourceid)
    divs = Doc.find_all_by_sourcedb_and_sourceid('PMC', sourceid)
    if divs.present?
      if (self.projects & divs.first.projects).size == 0
        divs = nil
        notice = I18n.t('controllers.application.get_divs.not_belong_to', :sourceid => sourceid, :project_name => name)
      end
    else
      divs = nil
      notice = I18n.t('controllers.application.get_divs.no_annotation', :sourceid => sourceid) 
    end

    return divs, notice
  end
  
  def increment_counters(project)
    Sproject.update_counters self.id, 
      :pmdocs_count => project.pmdocs_count,
      :pmcdocs_count => project.pmcdocs_count,
      :denotations_count => project.denotations_count,
      :relations_count => project.relations_count
  end
end