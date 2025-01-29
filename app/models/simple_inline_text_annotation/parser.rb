class SimpleInlineTextAnnotation
  class Parser
    # DENOTATION_PATTERN matches two consecutive pairs of square brackets.
    # Example: [Annotated Text][Label]
    DENOTATION_PATTERN = /(?<!\\)\[([^\[]+?)\]\[([^\]]+?)\]/

    def initialize(source)
      @source = source.dup.freeze
      @denotations = []
      @entity_type_collection = EntityTypeCollection.new(source)
    end

    def parse
      full_text = source_without_references

      while full_text =~ DENOTATION_PATTERN
        match = Regexp.last_match
        target_text = match[1]
        label = match[2]

        begin_pos = match.begin(0)
        end_pos = begin_pos + target_text.length
        obj = get_obj_for(label)

        @denotations << Denotation.new(begin_pos, end_pos, obj)

        # Replace the processed annotation with its text content
        full_text[match.begin(0)...match.end(0)] = target_text
      end

      SimpleInlineTextAnnotation.new(
        full_text,
        @denotations,
        @entity_type_collection
      )
    end

    private

    # Remove references from the source.
    def source_without_references
      @source.gsub(ENTITY_TYPE_BLOCK_PATTERN) do |block|
        block.start_with?("\n\n") ? "\n\n" : ""
      end.strip
    end

    def get_obj_for(label)
      @entity_type_collection.get(label) || label
    end
  end
end
