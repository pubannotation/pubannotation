class Doc < ActiveRecord::Base
  attr_accessible :body, :section, :serial, :source, :sourcedb, :sourceid
  has_many :denotations
  has_many :instances, :through => :denotations

  has_many :subcatrels, :class_name => 'Relation', :through => :denotations, :source => :subrels
  has_many :subinsrels, :class_name => 'Relation', :through => :instances, :source => :subrels
  #has_many :objcatrels, :class_name => 'Relation', :through => :denotations, :source => :objrels
  #has_many :objinsrels, :class_name => 'Relation', :through => :instances, :source => :objrels

  has_many :insmods, :class_name => 'Modification', :through => :instances, :source => :modifications
  has_many :subcatrelmods, :class_name => 'Modification', :through => :subcatrels, :source => :modifications
  has_many :subinsrelmods, :class_name => 'Modification', :through => :subinsrels, :source => :modifications

  has_and_belongs_to_many :projects
end
