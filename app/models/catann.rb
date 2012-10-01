class Catann < ActiveRecord::Base
  belongs_to :doc
  belongs_to :annset
  has_many :insanns, :as => :insobj, :dependent => :destroy
  has_many :relanns, :as => :relsub, :dependent => :destroy
  has_many :relanns, :as => :relobj, :dependent => :destroy
  has_many :modanns, :through => :insanns

  attr_accessible :begin, :category, :end, :hid

  validates :hid,       :presence => true
  validates :category,  :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :annset_id, :presence => true 
end
