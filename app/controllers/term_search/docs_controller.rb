# frozen_string_literal: true

module TermSearch
  class DocsController < ApplicationController
    def index
      @docs = Doc.all
      render json: @docs
    end
  end
end