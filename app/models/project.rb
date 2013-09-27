class Project < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :docs, :after_add => :increment_docs_counter, :after_remove => :decrement_docs_counter 
  has_and_belongs_to_many :pmdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PubMed'}
  has_and_belongs_to_many :pmcdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PMC'}
  has_many :projects_sprojects
  has_and_belongs_to_many :sprojects

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
  scope :sprojects_projects, lambda{|project_ids|
    where('projects.id IN (?)', project_ids)
  }
  scope :not_sprojects_projects, lambda{|project_ids|
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
    if doc.sourcedb == 'PMC'
      counter_column = :pmcdocs_count
    else
      counter_column = :pmdocs_count
    end
    Project.increment_counter(counter_column, self.id)
    if self.sprojects.present?
      self.sprojects.each do |sproject|
        Sproject.increment_counter(counter_column, sproject.id)
      end          
    end
  end
  
  # after_remove doc
  def decrement_docs_counter(doc)
    if doc.sourcedb == 'PMC'
      counter_column = :pmcdocs_count
    else
      counter_column = :pmdocs_count
    end
    Project.decrement_counter(counter_column, self.id)
    if self.sprojects.present?
      self.sprojects.each do |sproject|
        Sproject.decrement_counter(counter_column, sproject.id)
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
end
