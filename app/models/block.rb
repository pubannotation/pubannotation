class Block < ActiveRecord::Base
  belongs_to :project
  belongs_to :doc

  has_many :subrels, :class_name => 'Relation', :as => :subj, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :obj, :dependent => :destroy

  attr_accessible :hid, :begin, :end, :category

  validates :hid,       :presence => true
  validates :begin,     :presence => true
  validates :end,       :presence => true
  validates :category,  :presence => true
  validates :project_id, :presence => true
  validates :doc_id,    :presence => true

  def get_hash
    hblock = Hash.new
    hblock[:id]       = hid
    hblock[:begin]    = self.begin
    hblock[:end]      = self.end
    hblock[:category] = category
    hblock
  end
end
