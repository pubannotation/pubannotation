class Project < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :docs, :after_add => :increment_docs_counter, :after_remove => :decrement_docs_counter 
  has_and_belongs_to_many :pmdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PubMed'}
  has_and_belongs_to_many :pmcdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PMC', :serial => 0}
  
  # Project to Proejct associations
  # parent project => associate projects = @project.associate_projects
  has_and_belongs_to_many :associate_projects, 
    :foreign_key => 'project_id', 
    :association_foreign_key => 'associate_project_id', 
    :join_table => 'associate_projects_projects',
    :class_name => 'Project', 
    :after_add => :increment_counters, 
    :after_remove => :decrement_counters
    
  # associate projects => parent projects = @project.projects
  has_and_belongs_to_many :projects, 
    :foreign_key => 'associate_project_id',
    :association_foreign_key => 'project_id',
    :join_table => 'associate_projects_projects'

  attr_accessible :name, :description, :author, :license, :status, :accessibility, :reference, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter
  has_many :denotations, :dependent => :destroy
  has_many :relations, :dependent => :destroy
  has_many :instances, :dependent => :destroy
  has_many :modifications, :dependent => :destroy
  has_many :associate_maintainers, :dependent => :destroy
  has_many :associate_maintainer_users, :through => :associate_maintainers, :source => :user, :class_name => 'User'
  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}
  
  default_scope where(:type => nil)
  scope :accessible, lambda{|current_user|
    if current_user.present?
      where('accessibility = ? OR projects.user_id =?', 1, current_user.id)
    else
      where(:accessibility => 1)
    end
  }
  scope :not_id_in, lambda{|project_ids|
    where('projects.id NOT IN (?)', project_ids)
  }
    
  # scopes for order
  scope :order_pmdocs_count, 
    joins("LEFT OUTER JOIN docs_projects ON docs_projects.project_id = projects.id LEFT OUTER JOIN docs ON docs.id = docs_projects.doc_id AND docs.sourcedb = 'PubMed'").
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_pmcdocs_count, 
    joins("LEFT OUTER JOIN docs_projects ON docs_projects.project_id = projects.id LEFT OUTER JOIN docs ON docs.id = docs_projects.doc_id AND docs.sourcedb = 'PMC'").
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_denotations_count, 
    joins('LEFT OUTER JOIN denotations ON denotations.project_id = projects.id').
    group('projects.id').
    order("count(denotations.id) DESC")
    
  scope :order_relations_count,
    joins('LEFT OUTER JOIN relations ON relations.project_id = projects.id').
    group('projects.id').
    order('count(relations.id) DESC')
    
  scope :order_author,
    order('author ASC')
    
  scope :order_maintainer,
    joins('LEFT OUTER JOIN users ON users.id = projects.user_id').
    group('projects.id, users.username').
    order('users.username ASC')
  
  scope :order_association, lambda{|current_user|
    if current_user.present?
      joins("LEFT OUTER JOIN associate_maintainers ON projects.id = associate_maintainers.project_id AND associate_maintainers.user_id = #{current_user.id}").
      order("CASE WHEN projects.user_id = #{current_user.id} THEN 2 WHEN associate_maintainers.user_id = #{current_user.id} THEN 1 ELSE 0 END DESC")
    end
  }
  
  STATUS_HASH = {
    1 => I18n.t('activerecord.options.project.status.released'),
    2 => I18n.t('activerecord.options.project.status.beta'),
    3 => I18n.t('activerecord.options.project.status.developing')
  }

  ACCESSIBILITY_HASH = {
    1 => I18n.t('activerecord.options.project.accessibility.public'),
    2 => :Private
  }
  
  def status_text
   STATUS_HASH[self.status]
  end
  
  def accessibility_text
   ACCESSIBILITY_HASH[self.accessibility]
  end

  def self.order_by(projects, order, current_user)
    case order
    when 'pmdocs_count', 'pmcdocs_count', 'denotations_count', 'relations_count'
      projects.accessible(current_user).order("#{order} DESC")
    when 'author'
      projects.accessible(current_user).order_author
    when 'maintainer'
      projects.accessible(current_user).order_maintainer
    else
      # 'association' or nil
      projects.accessible(current_user).order_association(current_user)
    end    
  end
  
  # after_add doc
  def increment_docs_counter(doc)
    if doc.sourcedb == 'PMC' && doc.serial == 0
      counter_column = :pmcdocs_count
    elsif doc.sourcedb == 'PubMed'
      counter_column = :pmdocs_count
    end
    if counter_column
      Project.increment_counter(counter_column, self.id)
      if self.projects.present?
        self.projects.each do |project|
          Project.increment_counter(counter_column, project.id)
        end          
      end
    end
  end
  
  # after_remove doc
  def decrement_docs_counter(doc)
    if doc.sourcedb == 'PMC' && doc.serial == 0
      counter_column = :pmcdocs_count
    elsif doc.sourcedb == 'PubMed'
      counter_column = :pmdocs_count
    end
    if counter_column
      Project.decrement_counter(counter_column, self.id)
      if self.projects.present?
        self.projects.each do |project|
          Project.decrement_counter(counter_column, project.id)
        end          
      end          
    end          
  end          

  def associate_maintaines_addable_for?(current_user)
    current_user == self.user
  end
  
  def updatable_for?(current_user)
    current_user == self.user || self.associate_maintainer_users.include?(current_user)
  end

  def destroyable_for?(current_user)
    current_user == user  
  end
  
  def association_for(current_user)
    if current_user.present?
      if current_user == self.user
        'M'
      elsif self.associate_maintainer_users.include?(current_user)
        'A'
      end
    end
  end
    
  def build_associate_maintainers(usernames)
    if usernames.present?
      usernames.each do |username|
        user = User.where(:username => username).first
        self.associate_maintainers.build({:user_id => user.id})
      end
    end
  end
  
  def add_associate_projects(params_associate_projects)
    if params_associate_projects.present?
      associate_projects_names = Array.new
      params_associate_projects[:name].each do |index, name|
        associate_projects_names << name
        if params_associate_projects[:import].present? && params_associate_projects[:import][index]
          project = Project.includes(:associate_projects).find_by_name(name)
          if project.associate_projects.present?
            associate_project_names = project.associate_projects.collect{|associate_project| associate_project.name}
            associate_projects_names = associate_projects_names | associate_project_names if associate_project_names.present?
          end
        end
      end
      associate_projects = Project.where('name IN (?)', associate_projects_names.uniq)
      self.associate_projects << associate_projects
    end    
  end
  
  def associate_project_ids
    associate_project_ids = associate_projects.present? ? associate_projects.collect{|associate_project| associate_project.id} : []
    associate_project_ids.uniq
  end
  
  def self_id_and_associate_project_ids
    associate_project_ids << self.id
  end
  
  def project_ids
    project_ids = projects.present? ? projects.collect{|project| project.id} : []
    project_ids.uniq
  end
  
  def associate_project_and_project_ids
    if associate_project_ids.present? || project_ids.present?
      associate_project_ids | project_ids
    else
      [0]
    end
  end
  
  # increment counters after add associate projects
  def increment_counters(associate_project)
    Project.update_counters self.id, 
      :pmdocs_count => associate_project.pmdocs_count,
      :pmcdocs_count => associate_project.pmcdocs_count,
      :denotations_count => associate_project.denotations_count,
      :relations_count => associate_project.relations_count
  end  
  
  # decrement counters after delete associate projects
  def decrement_counters(associate_project)
    Project.update_counters self.id, 
      :pmdocs_count => - associate_project.pmdocs_count,
      :pmcdocs_count => - associate_project.pmcdocs_count,
      :denotations_count => - associate_project.denotations_count,
      :relations_count => - associate_project.relations_count
  end  
end
