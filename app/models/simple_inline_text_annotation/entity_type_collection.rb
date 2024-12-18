class SimpleInlineTextAnnotation
  class EntityTypeCollection
    # ENTITY_TYPE_PATTERN matches a pair of square brackets which is followed by a colon and URL.
    # Example: [Label]: URL
    ENTITY_TYPE_PATTERN = /^\[([^\]]+)\]:\s+(.*)/

    def initialize(source)
      @source = source
    end

    def get(label)
      entity_types[label]
    end

    def to_config
      entity_types.map do |label, id|
        { id: id, label: label }
      end
    end

    def any?
      entity_types.any?
    end

    private

    def entity_types
      # entity_type is a Hash structured with label as key and id as value.

      # Structure:
      #   Key: Label (String) - The label defined within square brackets (e.g., "Person").
      #   Value: ID (String)  - The URL or value following the colon (e.g., "https://example.com/Person").

      # Example Input (Source):
      #   [Person]: https://example.com/Person
      #   [Organization]: https://example.com/Organization

      # Example Output (Hash):
      #   {
      #     "Person": "https://example.com/Person",
      #     "Organization": "https://example.com/Organization"
      #   }

      @entity_types ||= read_entities_from_source
    end

    def read_entities_from_source
      entity_types = {}

      @source.scan(ENTITY_TYPE_BLOCK_PATTERN).each do |block|
        block[0].each_line do |line|
          match = line.strip.match(ENTITY_TYPE_PATTERN)

          if match
            label, id = match[1], match[2]
            entity_types[label] ||= id
          end
        end
      end

      entity_types
    end
  end
end
