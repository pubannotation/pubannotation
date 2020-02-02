class ProjectDoc < ActiveRecord::Base
	belongs_to :project
	belongs_to :doc

  attr_accessible :denotations_num, :relations_num, :modifications_num

  scope :simple_paginate, -> (page, per = 10) {
    page = page.nil? ? 1 : page.to_i
    offset = (page - 1) * per
    offset(offset).limit(per)
  }

  def graph_uri
    doc_spec = doc.has_divs? ?
      "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/divs/{doc.serial}" :
      "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"
    project.graph_uri + doc_spec
  end

  def self.repair_denotation_counts
    connection.execute "update project_docs set (denotations_num) = (select count(*) from denotations where denotations.doc_id=project_docs.doc_id and denotations.project_id=project_docs.project_id)"
  end

  def self.repair_relation_counts
    connection.execute "update project_docs set (relations_num) = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = project_docs.doc_id and relations.project_id=project_docs.project_id)"
  end

  def self.repair_modification_counts
    connection.execute "update project_docs set (modifications_num) = row((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = project_docs.id and modifications.project_id=project_docs.project_id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=project_docs.doc_id and modifications.project_id=project_docs.project_id))"
  end
end
