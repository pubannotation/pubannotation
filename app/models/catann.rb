class Catann < ActiveRecord::Base
  belongs_to :doc
  belongs_to :annset

  has_many :insanns, :foreign_key => "insobj_id", :dependent => :destroy

  has_many :subrels, :class_name => 'Relann', :as => :relsub, :dependent => :destroy
  has_many :objrels, :class_name => 'Relann', :as => :relobj, :dependent => :destroy

  has_many :insmods, :class_name => 'Modann', :through => :insanns
  has_many :relmods, :class_name => 'Modann', :through => :relanns


  attr_accessible :begin, :category, :end, :hid

  validates :hid,       :presence => true
  validates :category,  :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :annset_id, :presence => true 
end
