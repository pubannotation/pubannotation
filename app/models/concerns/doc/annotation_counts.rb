# frozen_string_literal: true

module Doc::AnnotationCounts
  extend ActiveSupport::Concern

  def get_denotations_count(span = nil)
    span.nil? ? denotations_num : denotations.in_span(span).count
  end

  def get_blocks_count(span = nil)
    span.nil? ? blocks_num : blocks.in_span(span).count
  end

  def get_relations_count(span = nil)
    span.nil? ? relations_num : relations.with_denotations_in_span(span).count
  end
end
