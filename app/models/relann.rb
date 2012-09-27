class Relann < ActiveRecord::Base
  belongs_to :subject, :polymorphic => true
  belongs_to :object,  :polymorphic => true
  belongs_to :annset
  attr_accessible :hid, :relation
end
