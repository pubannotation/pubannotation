# frozen_string_literal: true

module TextStructureReferenceCollection
  def update_references(denotations)
    each { |structure| structure.update_references(denotations) }
  end
end
