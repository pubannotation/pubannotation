class Modification < ActiveRecord::Base
  belongs_to :project
  belongs_to :obj, :polymorphic => true

  attr_accessible :hid, :pred

  validates :hid, :presence => true
  validates :pred, :presence => true
  validates :obj, :presence => true

  def get_hash
    hmodification = Hash.new
    hmodification[:id] = hid
    hmodification[:pred] = pred
    hmodification[:obj] = obj.hid
    hmodification
  end
end
