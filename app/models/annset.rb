class Annset < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :docs

  attr_accessible :name, :description, :author, :license, :status, :accessibility, :reference, :viewer, :editor, :rdfwriter, :xmlwriter, :bionlpwriter
  has_many :catanns, :dependent => :destroy
  has_many :relanns, :dependent => :destroy
  has_many :insanns, :dependent => :destroy
  has_many :modanns, :dependent => :destroy

  validates :name, :presence => true, :length => {:minimum => 5, :maximum => 30}
end
