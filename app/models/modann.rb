class Modann < ActiveRecord::Base
  belongs_to :annset
  belongs_to :modobj, :polymorphic => true

  attr_accessible :hid, :modtype

  validates :hid,     :presence => true
  validates :modtype, :presence => true
end
