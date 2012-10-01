class Modann < ActiveRecord::Base
  belongs_to :modobj, :polymorphic => true
  belongs_to :annset

  attr_accessible :hid, :modtype

  validates :hid,     :presence => true
  validates :modtype, :presence => true
end
