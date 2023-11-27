# frozen_string_literal: true

module TermSearch
  class DocsController < ApplicationController
    include ArrayParameterConcern

    def index
      base_project = Project.accessible(current_user).find_by!(name: params[:base_project]) if params[:base_project].present?
      doc_fields = search_by_term base_project,
                                  params[:terms],
                                  params[:predicates],
                                  params[:projects],
                                  params[:page]&.to_i,
                                  params[:per]&.to_i

      respond_to do |format|
        format.json { send_doc_data(doc_fields.to_json, 'docs.json', 'application/json') }
        format.tsv { send_doc_data(Doc.hash_to_tsv(doc_fields), 'docs.tsv', 'text/tab-separated-values') }
      end
    rescue => e
      Rails.logger.error e.backtrace.join("\n") if Rails.env.test?
      raise
    end

    private

    def search_by_term(base_project, terms , predicates, projects, page, per)
      docs = base_project.present? ? base_project.docs : Doc.all

      if terms.present?
        docs = docs.with_terms to_array(terms),
                               current_user,
                               to_array(predicates),
                               to_array(projects)
      end

      docs.select('sourcedb', 'sourceid')
                       .simple_paginate(page || 1, per || 10)
                       .map(&:to_list_hash)
    end

    def send_doc_data(data, filename, type)
      send_data data,
                filename:,
                type:,
                disposition: 'inline'
    end
  end
end
