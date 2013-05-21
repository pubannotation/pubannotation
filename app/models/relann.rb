class Relann < ActiveRecord::Base
  belongs_to :project
  belongs_to :relsub, :polymorphic => true
  belongs_to :relobj, :polymorphic => true

  has_many :modanns, :as => :modobj, :dependent => :destroy

  attr_accessible :hid, :reltype

  validates :hid,       :presence => true
  validates :reltype,   :presence => true
  validates :relsub_id, :presence => true
  validates :relobj_id, :presence => true

  def get_hash
    hrelann = Hash.new
    hrelann[:id]     = hid
    hrelann[:type]    = reltype
    hrelann[:subject] = relsub.hid
    hrelann[:object]  = relobj.hid
    hrelann
  end
end
