class ProjectDoc < ActiveRecord::Base
  belongs_to :project
  belongs_to :doc
  has_many :denotations, through: :doc
  has_many :blocks, through: :doc
  has_many :subcatrels, class_name: 'Relation', :through => :denotations, :source => :subrels
  has_many :catmods, class_name: 'Modification', :through => :denotations, :source => :modifications
  has_many :subcatrelmods, class_name: 'Modification', :through => :subcatrels, :source => :modifications

  scope :simple_paginate, -> (page, per = 10) {
    page = page.nil? ? 1 : page.to_i
    offset = (page - 1) * per
    offset(offset).limit(per)
  }

  def get_annotations(span = nil,
                      context_size = nil,
                      is_sort = false,
                      options = {})
    _denotations = get_denotations(span, context_size, is_sort)
    _blocks = get_blocks(span, context_size, is_sort)
    _ranges = _denotations + _blocks
    ids = _ranges.map { _1.id } if span.present?

    _relations = get_relations_of(ids)

    if is_sort
      _relations = _relations.sort
    end

    if span.present?
      ids += _relations.pluck(:id)
    end

    hdenotations = _denotations.as_json
    hrelations = _relations.as_json
    if options[:discontinuous_span] == :bag
      hdenotations, hrelations = self.class.bag_denotations(hdenotations, hrelations)
    end

    {
      project: project.name,
      denotations: hdenotations,
      blocks: _blocks.as_json,
      relations: hrelations,
      attributes: _ranges.map { _1.attrivutes }.flatten.as_json,
      modifications: get_modifications_of(ids).as_json,
      namespaces: project.namespaces
    }.select { |k, v| v.present? }
  end

  def graph_uri
    project.graph_uri + "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"
  end

  def self.reset_counts_denotations
    connection.exec_query "UPDATE project_docs SET (denotations_num) = (SELECT count(*) FROM denotations WHERE denotations.doc_id=project_docs.doc_id and denotations.project_id=project_docs.project_id)"
  end

  def self.reset_counts_relations
    connection.exec_query "UPDATE project_docs SET (relations_num) = (SELECT count(*) FROM relations INNER JOIN denotations ON relations.subj_id=denotations.id and relations.subj_type='Denotation' WHERE denotations.doc_id = project_docs.doc_id and relations.project_id=project_docs.project_id)"
  end

  def self.reset_counts_modifications
    connection.exec_query "UPDATE project_docs SET (modifications_num) = row((SELECT count(*) FROM modifications INNER JOIN denotations ON modifications.obj_id=denotations.id and modifications.obj_type='Denotation' WHERE denotations.doc_id = project_docs.id and modifications.project_id=project_docs.project_id) + (SELECT count(*) FROM modifications INNER JOIN relations ON modifications.obj_id=relations.id and modifications.obj_type='Relation' INNER JOIN denotations ON relations.subj_id=denotations.id and relations.subj_type='Denotations' WHERE denotations.doc_id=project_docs.doc_id and modifications.project_id=project_docs.project_id))"
  end

  def reset_count_denotations
    ActiveRecord::Base.connection.exec_query "UPDATE project_docs SET (denotations_num) = (SELECT count(*) FROM denotations WHERE denotations.doc_id = #{doc_id} AND denotations.project_id = #{project_id}) WHERE project_docs.doc_id = #{doc_id} AND project_docs.project_id = #{project_id}"
  end

  def reset_count_relations
    ActiveRecord::Base.connection.exec_query "UPDATE project_docs SET (relations_num) = (SELECT count(*) FROM relations INNER JOIN denotations ON relations.subj_id=denotations.id AND relations.subj_type='Denotation' WHERE denotations.doc_id = #{doc_id} and relations.project_id = #{project_id}) WHERE project_docs.doc_id = #{doc_id} AND project_docs.project_id = #{project_id}"
  end

  def reset_count_modifications
    ActiveRecord::Base.connection.exec_query "UPDATE project_docs SET (modifications_num) = row((SELECT count(*) FROM modifications INNER JOIN denotations on modifications.obj_id = denotations.id and modifications.obj_type = 'Denotation' WHERE denotations.doc_id = #{doc_id} and modifications.project_id = #{project_id}) + (SELECT count(*) FROM modifications INNER JOIN relations on modifications.obj_id = relations.id and modifications.obj_type = 'Relation' INNER JOIN denotations on relations.subj_id = denotations.id and relations.subj_type = 'Denotations' WHERE denotations.doc_id = #{doc_id} and modifications.project_id = #{project_id})) WHERE project_docs.doc_id = #{doc_id} AND project_docs.project_id = #{project_id}"
  end

  def update_annotations_updated_at
    self.update_attribute(:annotations_updated_at, DateTime.now)
  end

  def self.bag_denotations(denotations, relations)
    raise unless denotations.respond_to?('each')
    raise unless relations.respond_to?('each')
    raise unless denotations.first.is_a?(Hash) if denotations.first
    raise unless relations.first.is_a?(Hash) if relations.first

    # To merge spans of denotations that are lexically chained.
    merged_denotations = {}

    relations.each do |ra|
      if ra[:pred] == '_lexicallyChainedTo'
        # To see if either subject or object is already merged to another.
        ra[:subj] = merged_denotations[ra[:subj]] if merged_denotations.has_key? ra[:subj]
        ra[:obj] = merged_denotations[ra[:obj]] if merged_denotations.has_key? ra[:obj]

        # To find the indexes of the subject and object
        idx_from = denotations.find_index{|d| d[:id] == ra[:subj]}
        idx_to   = denotations.find_index{|d| d[:id] == ra[:obj]}
        from = denotations[idx_from]
        to   = denotations[idx_to]

        from[:span] = [from[:span]] unless from[:span].respond_to?('push')
        to[:span]   = [to[:span]]   unless to[:span].respond_to?('push')

        # To merge the two spans (in the reverse order)
        from[:span] = to[:span] + from[:span]

        # To delete the object denotation
        denotations.delete_at(idx_to)

        # To update the merged denotations
        merged_denotations[ra[:obj]] = ra[:subj]
      end
    end

    relations.delete_if{|ra| ra[:pred] == '_lexicallyChainedTo'}

    return denotations, relations
  end

  private

  def get_denotations(span, context_size, sort)
    ret = denotations.in_project(project).in_span(span)
    RangeArranger.new(ret, span, context_size, sort).call.ranges
  end

  def get_blocks(span, context_size, sort)
    ret = blocks.in_project(project).in_span(span)
    RangeArranger.new(ret, span, context_size, sort).call.ranges
  end

  def get_relations_of(base_ids)
    subcatrels.in_project(project).among_denotations(base_ids)
  end

  def get_modifications_of(base_ids)
    catmods.in_project(project).among_entities(base_ids) +
      subcatrelmods.in_project(project).among_entities(base_ids)
  end
end
