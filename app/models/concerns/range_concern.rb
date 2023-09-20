# frozen_string_literal: true

module RangeConcern
  extend ActiveSupport::Concern

  def moveForward(offset)
    self.begin -= offset
    self.end -= offset
  end

  def <=>(other)
    (self.begin <=> other.begin).nonzero? || (self.end <=> other.end)
  end
end
