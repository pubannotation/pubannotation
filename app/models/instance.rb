class Instance < ActiveRecord::Base
  belongs_to :project
  belongs_to :obj, :class_name => 'Span'

  has_many :subrels, :class_name => 'Relation', :as => :relsub, :dependent => :destroy
  has_many :objrels, :class_name => 'Relation', :as => :relobj, :dependent => :destroy

  has_many :modifications, :as => :modobj, :dependent => :destroy

  attr_accessible :hid, :pred

  validates :hid,     :presence => true
  validates :pred, :presence => true

  def get_hash
    hinstance = Hash.new
    hinstance[:id]    = hid
    hinstance[:type]   = pred
    hinstance[:object] = obj.hid
    hinstance
  end
end
