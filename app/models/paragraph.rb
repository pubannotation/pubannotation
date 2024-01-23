# frozen_string_literal: true

class Paragraph < ApplicationRecord
  include TermSearchConcern
  include PaginateConcern
  include Rails.application.routes.url_helpers

  self.table_name = 'divisions'
  default_scope { where label: Pubann::Paragraph::Labels }

  belongs_to :doc
  has_many :paragraph_attrivutes, foreign_key: :division_id
  has_many :attrivutes, through: :paragraph_attrivutes
  has_many :paragraph_denotations, foreign_key: :division_id
  has_many :denotations, through: :paragraph_denotations

  def self.search_by_term(user, base_project_name, terms, predicates, projects, page, per)
    base_project = Project.accessible(user).find_by!(name: base_project_name) if base_project_name.present?
    paragraphs = base_project.present? ? Paragraph.where(docs: base_project.docs) : Paragraph.all

    if terms.present?
      paragraphs = paragraphs.with_terms terms,
                                         user,
                                         predicates,
                                         projects
    end

    paragraphs.simple_paginate(page, per).tap { |q| logger.debug q.to_sql }
              .map(&:to_list_hash)
  end

  def to_list_hash
    {
      url: doc_sourcedb_sourceid_show_url(doc.sourcedb, doc.sourceid),
      begin: self.begin,
      end: self.end
    }
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

  private

  def range
    @range ||= (self.begin..self.end)
  end
end
