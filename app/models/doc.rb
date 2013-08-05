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
  
  scope :pmdocs, where(:sourcedb => 'PubMed')
  scope :pmcdocs, where(:sourcedb => 'PMC', :serial => 0)
  scope :project_name, lambda{|project_name|
    {:joins => :projects,
     :conditions => ['projects.name =?', project_name]  
    }
   }
  scope :denotations_count,
    joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id").
    group('docs.id').
    order("count(denotations.id) DESC")

  scope :relations_count,
    # LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN instances ON instances.obj_id = denotations.id LEFT OUTER JOIN relations ON relations.subj_id = instances.id AND relations.subj_type = 'Instance'
    #joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN instances ON instances.obj_id = denotations.id LEFT OUTER JOIN relations ON relations.subj_id = instances.id AND relations.subj_type = 'Instance' LEFT OUTER JOIN denotations denotations_docs_join ON denotations_docs_join.doc_id = docs.id LEFT OUTER JOIN relations subcatrels_docs ON subcatrels_docs.subj_id = denotations_docs_join.id AND subcatrels_docs.subj_type = 'Denotation'").
    #joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN relations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotation'")
    # order by subcatrels only
    joins("LEFT OUTER JOIN denotations ON denotations.doc_id = docs.id LEFT OUTER JOIN relations ON relations.subj_id = denotations.id AND relations.subj_type = 'Denotation'")
    .group('docs.id')
    .order('count(relations.id) DESC')
  
  def self.order_by(docs, order)
    case order
    when 'denotations_count'
      docs.denotations_count
    when 'same_sourceid_denotations_count'
      docs.sort{|a, b| b.same_sourceid_denotations_count <=> a.same_sourceid_denotations_count}
    when 'relations_count'
      docs.relations_count
    when 'same_sourceid_relations_count'
      docs.sort{|a, b| b.same_sourceid_relations_count <=> a.same_sourceid_relations_count}
    else
      docs.sort{|a, b| a.sourceid.to_i <=> b.sourceid.to_i}
    end    
  end    
  
  # returns relations count which belongs to project and doc
  def project_relations_count(project_id)
    count =   Relation.project_relations_count(project_id, subcatrels)
    count +=  Relation.project_relations_count(project_id, subinsrels)
  end
  
  # returns doc.relations count
  def relations_count
    subcatrels.size# + subinsrels.size
  end
  
  def same_sourceid_denotations_count
    denotation_doc_ids = Doc.where(:sourceid => self.sourceid).collect{|doc| doc.id}
    Denotation.select('doc_id').where('doc_id IN (?)', denotation_doc_ids).size
  end

  def same_sourceid_relations_count
    denotation_doc_ids = Doc.where(:sourceid => self.sourceid).collect{|doc| doc.id}
    denotations_ids = Denotation.select('id, doc_id').where('doc_id IN (?)', denotation_doc_ids).collect{|denotation| denotation.id}
    relations_size = Relation.select('subj_id, subj_type').where(:subj_type => 'Denotation').where('subj_id IN(?)', denotations_ids).size
    instances_size = Instance.select('obj_id').where('obj_id IN(?)', denotations_ids).size
    relations_size + instances_size
  end
end
