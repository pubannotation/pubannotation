# frozen_string_literal: true

module TermSearch
  class DocsController < ApplicationController
    def index
      if params[:base_project].present?
        base_project = Project.accessible(current_user).find_by!(name: params[:base_project])
      end

      docs = Doc.all
      docs = docs.joins(:project_docs).where(project_docs: { project: base_project }) if base_project.present?

      doc_fields = docs.select('sourcedb', 'sourceid').map(&:to_list_hash)

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
