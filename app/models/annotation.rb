# frozen_string_literal: true

class Annotation
  include DenotationBagger

  def initialize(project, denotations, blocks, relations, modifications, is_bag)
    @project = project
    @denotations = denotations
    @blocks = blocks
    @relations = relations
    @modifications = modifications
    @is_bag = is_bag
  end

  def as_json(options = {})
    denotations = @denotations.as_json
    relations = @relations.as_json
    denotations, relations = bag_denotations(denotations, relations) if @is_bag

    {
      project: @project.name,
      denotations:,
      blocks: @blocks.as_json,
      relations:,
      attributes: attributes.as_json,
      modifications: @modifications.as_json,
      namespaces: @project.namespaces
    }.select { |_, v| v.present? }
  end

  private

  def attributes
    (@denotations + @blocks).map { _1.attrivutes }.flatten
  end
end
