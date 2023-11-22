# frozen_string_literal: true

module ArrayParameterConcern
  extend ActiveSupport::Concern

  def to_array(str)
    str.split(',').map(&:strip).uniq if str.present?
  end
end
