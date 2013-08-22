class Project < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :docs
  has_and_belongs_to_many :pmdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PubMed'}
  has_and_belongs_to_many :pmcdocs, :join_table => :docs_projects, :class_name => 'Doc', :conditions => {:sourcedb => 'PMC'}

  attr_accessible :name, :description, :author, :license, :status, :accessibility, :reference, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter
  has_many :denotations, :dependent => :destroy
  has_many :relations, :dependent => :destroy
  has_many :instances, :dependent => :destroy
  has_many :modifications, :dependent => :destroy
  has_many :associate_maintainers, :dependent => :destroy

  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}
  
  scope :accessible, lambda{|current_user|
    if current_user.present?
      where('accessibility = ? OR projects.user_id =?', 1, current_user.id)
    else
      where(:accessibility => 1)
    end
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

  def self.order_by(projects, order, current_user)
    case order
    when 'pmdocs_count'
      projects.accessible(current_user).order_pmdocs_count
    when 'pmcdocs_count'
      projects.accessible(current_user).order_pmcdocs_count
    when 'denotations_count'
      projects.accessible(current_user).order_denotations_count
    when 'relations_count'
      projects.accessible(current_user).order_relations_count
    when 'author'
      projects.accessible(current_user).order_author
    when 'maintainer'
      projects.accessible(current_user).order_maintainer
    else
      projects.accessible(current_user).order('name ASC')
    end    
  end
  
  def associate_maintaines_addable_for?(current_user)
    current_user == self.user
  end
  
  def updatable_for?(current_user)
    assiate_maintainer_users = associate_maintainers.collect{|associate_maintainer| associate_maintainer.user}
    current_user == self.user || assiate_maintainer_users.include?(current_user)
  end

  def destroyable_for?(current_user)
    current_user == user  
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
