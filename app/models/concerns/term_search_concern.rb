# frozen_string_literal: true

module TermSearchConcern
  extend ActiveSupport::Concern

  included do
    scope :with_terms, lambda { |terms, user, predicates, project_names|
      base_query = joins(:attrivutes).joins(attrivutes: :project)
                                     .merge(Project.accessible(user))
      base_query = base_query.where(projects: { name: project_names }) if project_names.present?

      # Search attributes
      attributes_query = base_query.where(attrivutes: { obj: terms })
      predicates_for_attrivutes = predicates.reject { |p| p == 'denotes' } if predicates.present?
      attributes_query = attributes_query.where(attrivutes: { pred: predicates_for_attrivutes }) if predicates_for_attrivutes.present?
      attributes_query = attributes_query.joins(attrivutes: :doc)
                                         .select(:doc_id, 'docs.sourcedb', :'docs.sourceid')

      # Search denotations
      if predicates&.include?('denotes')
        base_query = joins(:denotations).joins(denotations: :project)
                                        .merge(Project.accessible(user))
        base_query = base_query.where(projects: { name: project_names }) if project_names.present?
        denotes_query = base_query.where(denotations: { obj: terms })
                                  .joins(denotations: :doc)
                                  .select(:doc_id, 'docs.sourcedb', :'docs.sourceid')

        attributes_query.union(denotes_query)
      else
        attributes_query.distinct
      end
    }

    scope :with_terms_with_begin_end, lambda { |terms, user, predicates, project_names|
      base_query = joins(:attrivutes).joins(attrivutes: :project)
                                     .merge(Project.accessible(user))
      base_query = base_query.where(projects: { name: project_names }) if project_names.present?

      # Search attributes
      attributes_query = base_query.where(attrivutes: { obj: terms })
      predicates_for_attrivutes = predicates.reject { |p| p == 'denotes' } if predicates.present?
      attributes_query = attributes_query.where(attrivutes: { pred: predicates_for_attrivutes }) if predicates_for_attrivutes.present?
      attributes_query = attributes_query.joins(attrivutes: :doc)
                                         .select(:doc_id, :begin, :end, 'docs.sourcedb', :'docs.sourceid')

      # Search denotations
      if predicates&.include?('denotes')
        base_query = joins(:denotations).joins(denotations: :project)
                                        .merge(Project.accessible(user))
        base_query = base_query.where(projects: { name: project_names }) if project_names.present?
        denotes_query = base_query.where(denotations: { obj: terms })
                                  .joins(denotations: :doc)
                                  .select(:doc_id, :begin, :end, 'docs.sourcedb', :'docs.sourceid')

        attributes_query.union(denotes_query)
      else
        attributes_query.distinct
      end
    }
  end
end
