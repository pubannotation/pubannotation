class Doc < ActiveRecord::Base
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid
  has_many :spans
  has_many :insanns, :through => :spans

  has_many :subcatrels, :class_name => 'Relation', :through => :spans, :source => :subrels
  has_many :subinsrels, :class_name => 'Relation', :through => :insanns, :source => :subrels
  #has_many :objcatrels, :class_name => 'Relation', :through => :spans, :source => :objrels
  #has_many :objinsrels, :class_name => 'Relation', :through => :insanns, :source => :objrels

  has_many :insmods, :class_name => 'Modification', :through => :insanns, :source => :modifications
  has_many :subcatrelmods, :class_name => 'Modification', :through => :subcatrels, :source => :modifications
  has_many :subinsrelmods, :class_name => 'Modification', :through => :subinsrels, :source => :modifications

  has_and_belongs_to_many :projects
end
