# frozen_string_literal: true

class Annotation
  include DenotationBagger

  attr_reader :project, :denotations, :blocks, :relations, :attributes

  def initialize(project, denotations, blocks, relations, attributes)
    @project = project
    @denotations = denotations
    @blocks = blocks
    @relations = relations
    @attributes = attributes
  end

  def as_json(options = {})
    if(options[:is_sort])
      @denotations = @denotations.sort
      @blocks = @blocks.sort
      @relations = @relations.sort
    end

    if(options[:span])
      @denotations = TermOffsetAdjuster.new(@denotations, options[:span], options[:context_size]).call.terms
      @blocks = TermOffsetAdjuster.new(@blocks, options[:span], options[:context_size]).call.terms
    end

    denotations = @denotations.as_json
    relations = @relations.as_json

    if(options[:is_bag_denotations])
      denotations, relations = bag_denotations(denotations, relations)
    end

    {
      project: @project.name,
      denotations:,
      blocks: @blocks.as_json,
      relations:,
      attributes: @attributes.as_json,
      namespaces: @project.namespaces
    }.select { |_, v| v.present? }
  end

  def self.delete_orphan_annotations
    ActiveRecord::Base.connection.delete("DELETE FROM denotations WHERE NOT EXISTS (SELECT 1 FROM project_docs WHERE project_docs.doc_id = denotations.doc_id)")
    ActiveRecord::Base.connection.delete("DELETE FROM blocks WHERE NOT EXISTS (SELECT 1 FROM project_docs WHERE project_docs.doc_id = blocks.doc_id)")
    ActiveRecord::Base.connection.delete("DELETE FROM relations WHERE NOT EXISTS (SELECT 1 FROM project_docs WHERE project_docs.doc_id = relations.doc_id)")
    ActiveRecord::Base.connection.delete("DELETE FROM attrivutes WHERE NOT EXISTS (SELECT 1 FROM project_docs WHERE project_docs.doc_id = attrivutes.doc_id)")
  end
end
