# frozen_string_literal: true

module Doc::AnnotationCounts
  extend ActiveSupport::Concern

  # returns relations count which belongs to project and doc
  def project_relations_num(project_id)
    ProjectDoc.relations_count_for(id, project_id)
  end

  def get_denotations_count(project_id = nil, span = nil)
    if project_id.nil? && span.nil?
      denotations_num
    elsif span.nil?
      ProjectDoc.denotations_count_for(id, project_id)
    else
      denotations.in_project_and_span(project_id, span).count
    end
  end

  def get_blocks_count(project_id = nil, span = nil)
    if project_id.nil? && span.nil?
      blocks_num
    elsif span.nil?
      ProjectDoc.blocks_count_for(id, project_id)
    else
      blocks.in_project_and_span(project_id, span).count
    end
  end

  def get_relations_count(project_id = nil, span = nil)
    if project_id.nil? && span.nil?
      relations_num
    elsif span.nil?
      ProjectDoc.relations_count_for(id, project_id)
    else
      relations.with_denotations_in_span(span, project_id).count
    end
  end
end
