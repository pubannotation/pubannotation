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
