# frozen_string_literal: true

module RangeConcern
  extend ActiveSupport::Concern

  def moveForward(span, context_size)
    offset = offset_size_for(span, context_size)
    self.begin -= offset
    self.end -= offset
  end

  def <=>(other)
    (self.begin <=> other.begin).nonzero? || (self.end <=> other.end)
  end

  class_methods do
    def arrange_for(ranges, span, context_size, sort)
      ranges.each{ _1.moveForward(span, context_size) } if span.present?
      ranges = ranges.sort if sort
      ranges
    end
  end

  private

  def offset_size_for(span, context_size)
    offset = span[:begin]

    if context_size.present?
      offset -= context_size
      offset = 0 if offset < 0
    end

    offset
  end
end
