class Relation < ActiveRecord::Base
  belongs_to :project
  belongs_to :relsub, :polymorphic => true
  belongs_to :relobj, :polymorphic => true

  has_many :modifications, :as => :obj, :dependent => :destroy

  attr_accessible :hid, :reltype

  validates :hid,       :presence => true
  validates :reltype,   :presence => true
  validates :relsub_id, :presence => true
  validates :relobj_id, :presence => true

  def get_hash
    hrelation = Hash.new
    hrelation[:id]     = hid
    hrelation[:type]    = reltype
    hrelation[:subject] = relsub.hid
    hrelation[:object]  = relobj.hid
    hrelation
  end
end
