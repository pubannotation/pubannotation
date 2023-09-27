# frozen_string_literal: true

class Annotation
  include DenotationBagger

  def initialize(project, denotations, blocks, relations, attributes, modifications, is_bag)
    @project = project
    @denotations = denotations
    @blocks = blocks
    @relations = relations
    @attributes = attributes
    @modifications = modifications
    @is_bag = is_bag
  end

  def as_json(options = {})
    if(options[:is_sort])
      @denotations = @denotations.sort
      @blocks = @blocks.sort
      @relations = @relations.sort
    end

    denotations = @denotations.as_json
    relations = @relations.as_json
    denotations, relations = bag_denotations(denotations, relations) if @is_bag

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
