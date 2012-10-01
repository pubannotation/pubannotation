class Relann < ActiveRecord::Base
  belongs_to :relsub, :polymorphic => true
  belongs_to :relobj, :polymorphic => true
  belongs_to :annset
  has_many :modanns, :as => :modobj,  :dependent => :destroy

  attr_accessible :hid, :reltype

  validates :hid,     :presence => true
  validates :reltype, :presence => true
end
