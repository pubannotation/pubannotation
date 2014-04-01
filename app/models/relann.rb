class Relann < ActiveRecord::Base
  belongs_to :annset
  belongs_to :relsub, :polymorphic => true
  belongs_to :relobj, :polymorphic => true

  has_many :modanns, :as => :modobj, :dependent => :destroy

  attr_accessible :hid, :reltype

  validates :hid,       :presence => true
  validates :reltype,   :presence => true
  validates :relsub_id, :presence => true
  validates :relobj_id, :presence => true
end
