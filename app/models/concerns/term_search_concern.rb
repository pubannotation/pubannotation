# frozen_string_literal: true

module TermSearchConcern
  extend ActiveSupport::Concern

  included do
    scope :with_terms, lambda { |terms, user, predicates, project_names|
      with_attributes = search_in_attributes(terms, user, predicates, project_names)
                          .select(:doc_id, 'docs.sourcedb', :'docs.sourceid')

      if predicates.nil? || predicates&.include?('denotes')
        with_denotations = search_in_denotations(terms, user, project_names)
                             .select(:doc_id, 'docs.sourcedb', :'docs.sourceid')

        with_attributes.union(with_denotations)
      else
        with_attributes.distinct
      end
    }

    scope :with_terms_with_begin_end, lambda { |terms, user, predicates, project_names|
      with_attributes = search_in_attributes(terms, user, predicates, project_names)
                          .select(:doc_id, :begin, :end, 'docs.sourcedb', :'docs.sourceid')

      if predicates&.include?('denotes')
        with_denotations = search_in_denotations(terms, user, project_names)
                             .select(:doc_id, :begin, :end, 'docs.sourcedb', :'docs.sourceid')

        with_attributes.union(with_denotations)
      else
        with_attributes.distinct
      end
    }
  end

  class_methods do
    def search_in_attributes(terms, user, predicates, project_names)
      base_query = joins(:attrivutes).joins(attrivutes: :project)
                                     .merge(Project.accessible(user))
      base_query = base_query.where(projects: { name: project_names }) if project_names.present?

      attributes_query = base_query.where(attrivutes: { obj: terms })
      predicates_for_attrivutes = predicates.reject { |p| p == 'denotes' } if predicates.present?
      attributes_query = attributes_query.where(attrivutes: { pred: predicates_for_attrivutes }) if predicates_for_attrivutes.present?
      attributes_query.joins(attrivutes: :doc)
    end

    def search_in_denotations(terms, user, project_names)
      base_query = joins(:denotations).joins(denotations: :project)
                                      .merge(Project.accessible(user))
      base_query = base_query.where(projects: { name: project_names }) if project_names.present?
      base_query.where(denotations: { obj: terms })
                .joins(denotations: :doc)

    end
  end
end
