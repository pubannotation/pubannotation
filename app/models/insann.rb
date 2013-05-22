class Insann < ActiveRecord::Base
  belongs_to :project
  belongs_to :insobj, :class_name => 'Span'

  has_many :subrels, :class_name => 'Relation', :as => :relsub, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :relobj, :dependent => :destroy

  has_many :modifications, :as => :modobj, :dependent => :destroy

  attr_accessible :hid, :instype

  validates :hid,     :presence => true
  validates :instype, :presence => true

  def get_hash
    hinsann = Hash.new
    hinsann[:id]    = hid
    hinsann[:type]   = instype
    hinsann[:object] = insobj.hid
    hinsann
  end
end
