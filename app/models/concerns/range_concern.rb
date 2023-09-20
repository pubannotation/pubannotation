# frozen_string_literal: true

module RangeConcern
  extend ActiveSupport::Concern

  def moveForward(offset)
    self.begin -= offset
    self.end -= offset
  end
end
