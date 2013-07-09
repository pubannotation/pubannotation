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
      where(:user_id => current_user.id)
    else
      where(:accessibility => 1)
    end
  }
    
  # scopes for order
  scope :order_pmdocs_count, 
    includes(:pmdocs).
    group('projects.id').
    order("IFNULL(count(docs.id), 0) DESC")
    
  scope :order_pmcdocs_count, 
    includes(:pmcdocs).
    group('projects.id').
    order("IFNULL(count(docs.id), 0) DESC")
    
  scope :order_denotations_count, 
    includes(:denotations).
    group('projects.id').
    order("IFNULL(count(denotations.id), 0) DESC")
    
  scope :order_relations_count,
    #joins('LEFT OUTER JOIN relations ON relations.project_id = projects.id').
    includes(:relations).
    group('projects.id').
    order('IFNULL(count(relations.id), 0) DESC')
end
