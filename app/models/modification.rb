class Modification < ActiveRecord::Base
  belongs_to :project
  belongs_to :modobj, :polymorphic => true

  attr_accessible :hid, :modtype

  validates :hid,     :presence => true
  validates :modtype, :presence => true

  def get_hash
    hmodification = Hash.new
    hmodification[:id]    = hid
    hmodification[:type]   = modtype
    hmodification[:object] = modobj.hid
    hmodification
  end
end
