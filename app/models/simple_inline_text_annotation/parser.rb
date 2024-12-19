class SimpleInlineTextAnnotation::Parser
  # DENOTATION_PATTERN matches two consecutive pairs of square brackets.
  # Example: [Annotated Text][Label]
  DENOTATION_PATTERN = /(?<!\\)\[([^\[]+?)\]\[([^\]]+?)\]/

  def initialize(source)
    @source = source.dup.freeze
    @denotations = []
    @entity_type_collection = SimpleInlineTextAnnotation::EntityTypeCollection.new(source)
  end

  def parse
    full_text = source_without_references

    while full_text =~ DENOTATION_PATTERN
      match = Regexp.last_match
      target_text = match[1]
      label = match[2]

      begin_pos = match.begin(0)
      end_pos = begin_pos + target_text.length - 1 # -1 to adapt with zero-based indexing.
      obj = get_obj_for(label)

      @denotations << SimpleInlineTextAnnotation::Denotation.new(begin_pos, end_pos, obj)

      # Replace the processed annotation with its text content
      full_text[match.begin(0)...match.end(0)] = target_text
    end

    SimpleInlineTextAnnotation.new(
      full_text,
      @denotations,
      @entity_type_collection
    ).to_h
  end

  private

  def source_without_references
    # Remove references from the source.

    @source.gsub(SimpleInlineTextAnnotation::ENTITY_TYPE_BLOCK_PATTERN) do |block|
      block.start_with?("\n\n") ? "\n\n" : ""
    end.strip
  end

  def get_obj_for(label)
    @entity_type_collection.get(label) || label
  end
end
