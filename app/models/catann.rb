class Catann < ActiveRecord::Base
  belongs_to :annset
  belongs_to :doc

  has_many :insanns, :foreign_key => "insobj_id", :dependent => :destroy

  has_many :subrels, :class_name => 'Relann', :as => :relsub, :dependent => :destroy
  has_many :objrels, :class_name => 'Relann', :as => :relobj, :dependent => :destroy

  has_many :insmods, :class_name => 'Modann', :through => :insanns
  has_many :relmods, :class_name => 'Modann', :through => :relanns


  attr_accessible :hid, :begin, :end, :category

  validates :hid,       :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :category,  :presence => true
  validates :annset_id, :presence => true
  validates :doc_id,    :presence => true

  def get_hash
    hcatann = Hash.new
    hcatann[:id]       = hid
    hcatann[:span]     = {:begin => self.begin, :end => self.end}
    hcatann[:category] = category
    hcatann
  end
end
