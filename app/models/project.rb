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

  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}
  
  scope :accessible, lambda{|current_user|
    if current_user.present?
      where('accessibility = ? OR user_id =?', 1, current_user.id)
    else
      where(:accessibility => 1)
    end
  }
    
  # scopes for order
  scope :order_pmdocs_count, 
    includes(:pmdocs).
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_pmcdocs_count, 
    includes(:pmcdocs).
    group('projects.id').
    order("count(docs.id) DESC")
    
  scope :order_denotations_count, 
    includes(:denotations).
    group('projects.id').
    order("count(denotations.id) DESC")
    
  scope :order_relations_count,
    includes(:relations).
    group('projects.id').
    order('count(relations.id) DESC')

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
    else
      projects.accessible(current_user).order('name ASC')
    end    
  end
end
