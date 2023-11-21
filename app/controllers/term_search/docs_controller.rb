# frozen_string_literal: true

module TermSearch
  class DocsController < ApplicationController
    def index
      docs = Doc.all.map(&:to_list_hash)

      respond_to do |format|
        format.json do
          send_data docs.to_json,
                    filename: 'docs.json',
                    type: 'application/json',
                    disposition: 'inline'
        end
        format.tsv do
          send_data Doc.hash_to_tsv(docs),
                    filename: 'docs.tsv',
                    type: 'text/tab-separated-values',
                    disposition: 'inline'
        end
      end
    end
  end
end