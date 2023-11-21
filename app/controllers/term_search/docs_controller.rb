# frozen_string_literal: true

module TermSearch
  class DocsController < ApplicationController
    def index
      doc_fields = Doc.select('sourcedb', 'sourceid').map(&:to_list_hash)

      respond_to do |format|
        format.json { send_doc_data(doc_fields.to_json, 'docs.json', 'application/json') }
        format.tsv { send_doc_data(Doc.hash_to_tsv(doc_fields), 'docs.tsv', 'text/tab-separated-values') }
      end
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
