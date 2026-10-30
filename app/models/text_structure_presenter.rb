# frozen_string_literal: true

class TextStructurePresenter
  def initialize(structures, text_length)
    @structures = structures
    @text_length = text_length
  end

  def to_a(span = nil, context_size = nil)
    return @structures.map(&:to_hash) unless span.present?

    context_size ||= 0
    first = [span[:begin] - context_size, 0].max
    last = [span[:end] + context_size, @text_length].min
    @structures.select { |structure| structure.begin >= first && structure.end < last }.map do |structure|
      structure.begin -= first
      structure.end -= first
      structure.to_hash
    end
  end
end
