# frozen_string_literal: true

class RangeArranger
  attr_reader :ranges

  def initialize(ranges, span, context_size, sort)
    @ranges = ranges
    @span = span
    @offset_size = offset_size(span, context_size) if span.present?
    @sort = sort
  end

  def call
    @ranges.each{ moveForward _1 } if @offset_size.present?
    @ranges = @ranges.sort if @sort

    self
  end

  private

  def moveForward(range)
    range.begin -= @offset_size
    range.end -= @offset_size
  end

  def offset_size(span, context_size)
    offset = span[:begin]

    if context_size.present?
      offset -= context_size
      offset = 0 if offset < 0
    end

    offset
  end
end
