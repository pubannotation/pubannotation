class Insann < ActiveRecord::Base
  belongs_to :type, :class_name => "Catann", :polymorphic => true
  belongs_to :annset
  has_many :relanns, :as => :subject, :dependent => :destroy
  has_many :relanns, :as => :object,  :dependent => :destroy
  has_many :modanns, :as => :modobj,  :dependent => :destroy
  attr_accessible :hid
  validates :hid,       :presence => true
end
