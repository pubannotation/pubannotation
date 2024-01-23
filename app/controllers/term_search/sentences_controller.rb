# frozen_string_literal: true


module TermSearch
  class SentencesController < ApplicationController
    include ArrayParameterConcern

    def index
      data = Sentence.search_by_term current_user,
                                     params[:base_project],
                                     to_array(params[:terms]),
                                     to_array(params[:predicates]),
                                     to_array(params[:projects]),
                                     params[:page]&.to_i || 1,
                                     params[:per]&.to_i || 10

      respond_to do |format|
        format.json { send_sentence_data data.to_json, 'sentences.json', 'application/json' }
        format.tsv { send_sentence_data json_to_tsv(data), 'sentences.tsv', 'text/tab-separated-values' }
      end
    rescue => e
      Rails.logger.error e.backtrace.join("\n") if Rails.env.test?
      raise
    end

    private

    def send_sentence_data(data, filename, type)
      send_data data,
                filename:,
                type:,
                disposition: 'inline'
    end

    def json_to_tsv(json)
      json.map do |sentence|
        [
          sentence[:sourcedb],
          sentence[:sourceid],
          sentence[:begin],
          sentence[:end],
        ].join("\t")
      end.join("\n")
    end
  end
end

