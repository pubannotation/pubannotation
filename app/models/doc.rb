class Doc < ActiveRecord::Base
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid
  has_many :spans
  has_many :insanns, :through => :spans

  has_many :subcatrels, :class_name => 'Relann', :through => :spans, :source => :subrels
  has_many :subinsrels, :class_name => 'Relann', :through => :insanns, :source => :subrels
  #has_many :objcatrels, :class_name => 'Relann', :through => :spans, :source => :objrels
  #has_many :objinsrels, :class_name => 'Relann', :through => :insanns, :source => :objrels

  has_many :insmods, :class_name => 'Modann', :through => :insanns, :source => :modanns
  has_many :subcatrelmods, :class_name => 'Modann', :through => :subcatrels, :source => :modanns
  has_many :subinsrelmods, :class_name => 'Modann', :through => :subinsrels, :source => :modanns

  has_and_belongs_to_many :projects
end
