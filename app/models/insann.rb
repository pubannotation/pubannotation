class Insann < ActiveRecord::Base
  belongs_to :insobj, :polymorphic => true
  belongs_to :annset
  has_many :relanns, :as => :relsub, :dependent => :destroy
  has_many :relanns, :as => :relobj, :dependent => :destroy
  has_many :modanns, :as => :modobj, :dependent => :destroy

  attr_accessible :hid, :instype

  validates :hid,     :presence => true
  validates :instype, :presence => true
end
