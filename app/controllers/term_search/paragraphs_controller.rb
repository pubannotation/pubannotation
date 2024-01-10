# frozen_string_literal: true

module TermSearch
  class ParagraphsController < ApplicationController
    include ArrayParameterConcern

    def index
      data = Paragraph.search_by_term current_user,
                                      params[:base_project],
                                      to_array(params[:terms]),
                                      to_array(params[:predicates]),
                                      to_array(params[:projects]),
                                      params[:page]&.to_i || 1,
                                      params[:per]&.to_i || 10

      respond_to do |format|
        format.json { send_paragraph_data data.to_json, 'paragraphs.json', 'application/json' }
        format.tsv { send_paragraph_data json_to_tsv(data), 'paragraphs.tsv', 'text/tab-separated-values' }
      end
    rescue => e
      Rails.logger.error e.backtrace.join("\n") if Rails.env.test?
      raise
    end

    private

    def send_paragraph_data(data, filename, type)
      send_data data,
                filename:,
                type:,
                disposition: 'inline'
    end

    def json_to_tsv(json)
      json.map do |paragraph|
        [
          paragraph[:sourcedb],
          paragraph[:sourceid],
          paragraph[:begin],
          paragraph[:end],
        ].join("\t")
      end.join("\n")
    end
  end
end
