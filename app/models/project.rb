class Project < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :docs

  attr_accessible :name, :description, :author, :license, :status, :accessibility, :reference, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter
  has_many :spans, :dependent => :destroy
  has_many :relations, :dependent => :destroy
  has_many :instances, :dependent => :destroy
  has_many :modifications, :dependent => :destroy

  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}
end
