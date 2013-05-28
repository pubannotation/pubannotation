class Relation < ActiveRecord::Base
  belongs_to :project
  belongs_to :subj, :polymorphic => true
  belongs_to :obj, :polymorphic => true

  has_many :modifications, :as => :obj, :dependent => :destroy

  attr_accessible :hid, :pred

  validates :hid,       :presence => true
  validates :pred,   :presence => true
  validates :subj_id, :presence => true
  validates :obj_id, :presence => true

  def get_hash
    hrelation = Hash.new
    hrelation[:id]     = hid
    hrelation[:type]    = pred
    hrelation[:subject] = subj.hid
    hrelation[:object]  = obj.hid
    hrelation
  end
end
