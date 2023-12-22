# frozen_string_literal: true

module TermSearch
  class ParagraphsController < ApplicationController
    def index

      respond_to do |format|
        format.json do
          data = { message: 'hello' }
          send_data data.to_json,
                    filename: 'paragraphs.json',
                    type: 'application/json',
                    disposition: 'inline'
        end
      end
    end
  end
end
