class Modann < ActiveRecord::Base
  belongs_to :modobj, :polymorphic => true
  belongs_to :annset

  attr_accessible :hid, :modtype
end
