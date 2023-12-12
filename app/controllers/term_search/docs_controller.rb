# frozen_string_literal: true

module TermSearch
  class DocsController < ApplicationController
    include ArrayParameterConcern

    def index
      doc_fields = Doc.search_by_term current_user,
                                      params[:base_project],
                                      to_array(params[:terms]),
                                      to_array(params[:predicates]),
                                      to_array(params[:projects]),
                                      params[:page]&.to_i || 1,
                                      params[:per]&.to_i || 10

      respond_to do |format|
        format.json { send_doc_data(doc_fields.to_json, 'docs.json', 'application/json') }
        format.tsv { send_doc_data(Doc.hash_to_tsv(doc_fields), 'docs.tsv', 'text/tab-separated-values') }
      end
    rescue => e
      Rails.logger.error e.backtrace.join("\n") if Rails.env.test?
      raise
    end

    private

    def send_doc_data(data, filename, type)
      send_data data,
                filename:,
                type:,
                disposition: 'inline'
    end
  end
end
