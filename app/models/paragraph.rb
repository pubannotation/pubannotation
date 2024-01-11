# frozen_string_literal: true

class Paragraph < ApplicationRecord
  include Rails.application.routes.url_helpers
  include PaginateConcern

  self.table_name = 'divisions'
  default_scope { where label: Pubann::Paragraph::Labels }

  belongs_to :doc
  has_many :paragraph_attrivutes, foreign_key: :division_id
  has_many :attrivutes, through: :paragraph_attrivutes
  has_many :paragraph_denotations, foreign_key: :division_id
  has_many :denotations, through: :paragraph_denotations

  scope :with_terms, lambda { |terms, user, predicates, project_names|
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

  def self.search_by_term(user, base_project_name, terms, predicates, projects, page, per)
    base_project = Project.accessible(user).find_by!(name: base_project_name) if base_project_name.present?
    paragraphs = base_project.present? ? base_project.paragraphs : Paragraph.all

    if terms.present?
      paragraphs = paragraphs.with_terms terms,
                                         user,
                                         predicates,
                                         projects
    end

    paragraphs.simple_paginate(page, per).tap { |q| logger.debug q.to_sql }
              .map(&:to_list_hash)
  end

  def update_references(denotations)
    denotations.each do |denotation|
      if range.include?(denotation.range)
        paragraph_denotations.find_or_create_by denotation: denotation
        denotation.attrivutes.each do |attrivute|
          paragraph_attrivutes.find_or_create_by attrivute: attrivute
        end
      else
        paragraph_denotations.where(denotation: denotation).destroy_all
        denotation.attrivutes.each do |attrivute|
          paragraph_attrivutes.where(attrivute: attrivute).destroy_all
        end
      end
    end
  end

  def to_list_hash
    {
      url: doc_sourcedb_sourceid_show_url(doc.sourcedb, doc.sourceid),
      begin: self.begin,
      end: self.end
    }
  end

  private

  def range
    @range ||= (self.begin..self.end)
  end
end
