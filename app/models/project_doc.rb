class ProjectDoc < ActiveRecord::Base
  include PaginateConcern

  belongs_to :project
  belongs_to :doc
  has_many :denotations, through: :doc
  has_many :blocks, through: :doc
  has_many :relations, through: :project
  has_many :attrivutes, through: :project

  scope :without_denotations, -> { where(denotations_num: 0) }
  scope :with_denotations, -> { where('denotations_num > ?', 0) }

  def annotation_about(span, terms, predicates)
    _denotations = denotations_about span, terms, predicates
    _blocks = blocks_about span, terms, predicates

    ids = (_denotations + _blocks).pluck(:id)

    _relations = relations_about ids, terms, predicates
    ids += _relations.pluck(:id)

    Annotation.new(
      project,
      _denotations,
      _blocks,
      _relations,
      attributes_about(ids, predicates),
    )
  end

  def graph_uri
    project.graph_uri + "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"
  end

  def update_annotations_updated_at
    self.update_attribute(:annotations_updated_at, DateTime.now)
  end

  # annotations need to be normal
  def save_annotations(annotations, options = nil)
    options ||= {}

    return ['Upload is skipped due to existing annotations'] if options[:mode] == :skip && (denotations_num > 0 || blocks_num > 0)
    return ['The text in the annotations is no identical to the original document'] unless annotations[:text] == doc.body

    case options[:mode]
    when :replace
      delete_annotations(options[:span])
      reid_annotations!(annotations) if options[:span].present?
    when :add
      reid_annotations!(annotations)
    when :merge
      reid_annotations!(annotations)
      base_annotations = get_hannotations
      AnnotationUtils.prepare_annotations_for_merging!(annotations, base_annotations)
    else
      reid_annotations!(annotations) if options[:span].present?
    end

    project.instantiate_and_save_annotations(annotations, doc)

    []
  end

  def delete_annotations(span = nil)
    if span.present?
      Denotation.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', project_id, doc_id, span[:begin], span[:end]).destroy_all
      Block.where('project_id = ? AND doc_id = ? AND begin >= ? AND "end" <= ?', project_id, doc_id, span[:begin], span[:end]).destroy_all
    else
      ActiveRecord::Base.transaction do
        d_num = ActiveRecord::Base.connection.update("delete from denotations where project_id=#{project_id} AND doc_id=#{doc_id}")
        b_num = ActiveRecord::Base.connection.update("delete from blocks where project_id=#{project_id} AND doc_id=#{doc_id}")
        r_num = ActiveRecord::Base.connection.update("delete from relations where project_id=#{project_id} AND doc_id=#{doc_id}")
        a_num = ActiveRecord::Base.connection.update("delete from attrivutes where project_id=#{project_id} AND doc_id=#{doc_id}")

        if d_num > 0 || b_num > 0
          ActiveRecord::Base.connection.update("update project_docs set denotations_num = 0, blocks_num = 0, relations_num = 0, annotations_updated_at = CURRENT_TIMESTAMP where project_id=#{project_id} and doc_id=#{doc_id}")
          ActiveRecord::Base.connection.update("update docs set denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num} where id=#{doc_id}")
          ActiveRecord::Base.connection.update("update projects set denotations_num = denotations_num - #{d_num}, blocks_num = blocks_num - #{b_num}, relations_num = relations_num - #{r_num} where id=#{project_id}")

          project.update_annotations_updated_at
          project.update_updated_at
        end
      end
    end
  end

  # reassign ids to instances in annotations to avoid id confiction
  # ToDo: del the same one in the Project class
  def reid_annotations!(annotations)
    existing_ids = get_annotation_hids
    unless existing_ids.empty?
      id_change = {}
      if annotations.has_key?(:denotations)
        annotations[:denotations].each do |a|
          id = a[:id]
          id = Denotation.new_id while existing_ids.include?(id)
          if id != a[:id]
            id_change[a[:id]] = id
            a[:id] = id
            existing_ids << id
          end
        end
      end

      if annotations.has_key?(:blocks)
        Block.new_id_init
        annotations[:blocks].each do |a|
          id = a[:id]
          id = Block.new_id while existing_ids.include?(id)
          if id != a[:id]
            id_change[a[:id]] = id
            a[:id] = id
            existing_ids << id
          end
        end
      end

      if annotations.has_key?(:relations)
        Relation.new_id_init
        annotations[:relations].each do |a|
          id = a[:id]
          id = Relation.new_id while existing_ids.include?(id)
          if id != a[:id]
            id_change[a[:id]] = id
            a[:id] = id
            existing_ids << id
          end
          a[:subj] = id_change[a[:subj]] if id_change.has_key?(a[:subj])
          a[:obj] = id_change[a[:obj]] if id_change.has_key?(a[:obj])
        end
      end

      if annotations.has_key?(:attributes)
        Attrivute.new_id_init
        annotations[:attributes].each do |a|
          id = a[:id]
          id = Attrivute.new_id while existing_ids.include?(id)
          if id != a[:id]
            a[:id] = id
            existing_ids << id
          end
          a[:subj] = id_change[a[:subj]] if id_change.has_key?(a[:subj])
        end
      end
    end

    annotations
  end

  def get_annotation_hids
    denotation_hids = Denotation.in_doc(doc_id).in_project(project_id).pluck(:hid)
    block_hids = Block.in_doc(doc_id).in_project(project_id).pluck(:hid)

    return [] if denotation_hids.empty? && block_hids.empty?

    relation_hids = Relation.in_doc(doc_id).in_project(project_id).pluck(:hid)
    attribute_hids = Attrivute.in_doc(doc_id).in_project(project_id).pluck(:hid)

    denotation_hids + block_hids + relation_hids + attribute_hids
  end

  def get_hannotations
    hdenotations = Denotation.in_doc(doc_id).in_project(project_id).as_json
    hblocks = Block.in_doc(doc_id).in_project(project_id).as_json

    return [] if hdenotations.empty? && hblocks.empty?

    hrelations = Relation.in_doc(doc_id).in_project(project_id).as_json
    hattributes = Attrivute.in_doc(doc_id).in_project(project_id).as_json

    {denotations:hdenotations, blocks:hblocks, relations:hrelations, attributes:hattributes}
  end

  # Shared method to bulk update annotation counts for project_docs table
  # @param project_id [Integer, nil] Optional project ID to filter by
  # @param doc_ids [Array<Integer>, nil] Optional array of doc IDs to filter by
  # @param flagged_only [Boolean] If true, only update records where flag=true
  # @param update_timestamp [Boolean] If true, update annotations_updated_at timestamp
  def self.bulk_update_counts(project_id: nil, doc_ids: nil, flagged_only: false, update_timestamp: false)
    # Build WHERE clause components
    where_conditions = []
    where_conditions << "project_docs.project_id = #{project_id}" if project_id.present?
    where_conditions << "project_docs.doc_id IN (#{doc_ids.join(',')})" if doc_ids.present?
    where_conditions << "project_docs.flag = true" if flagged_only

    # Combine conditions - use AND to append to the base WHERE condition
    project_docs_where_clause = where_conditions.any? ? "AND #{where_conditions.join(' AND ')}" : ""

    # Add timestamp update if requested
    timestamp_update = update_timestamp ? ", annotations_updated_at = CURRENT_TIMESTAMP" : ""

    ActiveRecord::Base.connection.update <<~SQL.squish
      UPDATE project_docs
      SET
        denotations_num = COALESCE(d.cnt, 0),
        blocks_num = COALESCE(b.cnt, 0),
        relations_num = COALESCE(r.cnt, 0)
        #{timestamp_update}
      FROM
        project_docs pd_list
        LEFT JOIN (SELECT doc_id, project_id, COUNT(*) as cnt FROM denotations GROUP BY doc_id, project_id) d ON pd_list.doc_id = d.doc_id AND pd_list.project_id = d.project_id
        LEFT JOIN (SELECT doc_id, project_id, COUNT(*) as cnt FROM blocks GROUP BY doc_id, project_id) b ON pd_list.doc_id = b.doc_id AND pd_list.project_id = b.project_id
        LEFT JOIN (SELECT doc_id, project_id, COUNT(*) as cnt FROM relations GROUP BY doc_id, project_id) r ON pd_list.doc_id = r.doc_id AND pd_list.project_id = r.project_id
      WHERE project_docs.doc_id = pd_list.doc_id AND project_docs.project_id = pd_list.project_id
      #{project_docs_where_clause}
    SQL
  end

private

  def denotations_about(span, terms, predicates)
    denotations.in_project(project)
               .in_span(span)
               .with_terms(terms)
               .with_predicates(predicates)
  end

  def blocks_about(span, terms, predicates)
    blocks.in_project(project)
          .in_span(span)
          .with_terms(terms)
          .with_predicates(predicates)
  end

  def relations_about(base_ids, terms, predicates)
    return [] if terms.present? || predicates.present?

    relations.among_denotations(base_ids)
  end

  def attributes_about(base_ids, predicates)
    # The inucludes method is used to prevent searching denotation by attribute.
    query = attrivutes.includes(:subj)
                      .among_entities(base_ids)

    query = query.where(pred: predicates) if predicates

    query
  end
end
