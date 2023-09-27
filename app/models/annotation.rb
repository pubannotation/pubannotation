# frozen_string_literal: true

class Annotation
  include DenotationBagger

  attr_reader :project, :denotations, :blocks, :relations, :attributes, :modifications

  def initialize(project, denotations, blocks, relations, attributes, modifications)
    @project = project
    @denotations = denotations
    @blocks = blocks
    @relations = relations
    @attributes = attributes
    @modifications = modifications
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
      modifications: @modifications.as_json,
      namespaces: @project.namespaces
    }.select { |_, v| v.present? }
  end
end
