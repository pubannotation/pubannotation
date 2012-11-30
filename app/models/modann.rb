class Modann < ActiveRecord::Base
  belongs_to :annset
  belongs_to :modobj, :polymorphic => true

  attr_accessible :hid, :modtype

  validates :hid,     :presence => true
  validates :modtype, :presence => true

  def get_hash
    hmodann = Hash.new
    hmodann[:id]    = hid
    hmodann[:type]   = modtype
    hmodann[:object] = modobj.hid
    hmodann
  end
end
