# frozen_string_literal: true

module PaginateConcern
  extend ActiveSupport::Concern

  included do
    scope :simple_paginate, -> (page, per = 10) {
      page = page.nil? ? 1 : page.to_i
      offset = (page - 1) * per
      offset(offset).limit(per)
    }
  end
end
