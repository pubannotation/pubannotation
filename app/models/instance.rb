class Instance < ActiveRecord::Base
  belongs_to :project
  belongs_to :obj, :class_name => 'Span'

  has_many :subrels, :class_name => 'Relation', :as => :subj, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :obj, :dependent => :destroy

  has_many :modifications, :as => :obj, :dependent => :destroy

  attr_accessible :hid, :pred

  validates :hid,     :presence => true
  validates :pred, :presence => true

  def get_hash
    hinstance = Hash.new
    hinstance[:id]     = hid
    hinstance[:pred]   = pred
    hinstance[:obj] = obj.hid
    hinstance
  end
end
