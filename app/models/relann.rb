class Relann < ActiveRecord::Base
  belongs_to :subject, :polymorphic => true
  belongs_to :object,  :polymorphic => true
  belongs_to :annset
  has_many :modanns, :as => :modobj,  :dependent => :destroy
  attr_accessible :hid, :relation
end
