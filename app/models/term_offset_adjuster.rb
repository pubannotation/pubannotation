# frozen_string_literal: true

class TermOffsetAdjuster
  attr_reader :terms

  def initialize(terms, span, context_size)
    @terms = terms
    @span = span
    @offset_size = offset_size(span, context_size) if span.present?
  end

  def call
    @terms.each{ moveForward _1 } if @offset_size.present?

    self
  end

  private

  def moveForward(term)
    term.begin -= @offset_size
    term.end -= @offset_size
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
