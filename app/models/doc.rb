class Doc < ActiveRecord::Base
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid
  has_many :catanns
  has_many :relanns, :through => :catanns
  has_many :insanns, :through => :catanns
  has_many :annsets, :through => :catanns
end
