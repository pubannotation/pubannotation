class SimpleInlineTextAnnotation::EntityTypeCollection
  # ENTITY_TYPE_PATTERN matches a pair of square brackets which is followed by a colon and URL.
  # Example: [Label]: URL
  ENTITY_TYPE_PATTERN = /^\[([^\]]+)\]:\s+(.*)/

  def initialize(source)
    @source = source
  end

  def get(label)
    entity_types[label]
  end

  # to_config returns a Array of hashes of each entity type.
  # Example:
  #   [
  #     {id: "https://example.com/Person", label: "Person"},
  #     {id: "https://example.com/Organization", label: "Organization"}
  #   ]
  def to_config
    entity_types.map do |label, id|
      { id: id, label: label }
    end
  end

  def any?
    entity_types.any?
  end

  private

  # entity_types returns a Hash structured with label as key and id as value.
  # Example:
  #   {
  #     "Person": "https://example.com/Person",
  #     "Organization": "https://example.com/Organization"
  #   }
  def entity_types
    @entity_types ||= read_entities_from_source
  end

  def read_entities_from_source
    entity_types = {}

    @source.scan(SimpleInlineTextAnnotation::ENTITY_TYPE_BLOCK_PATTERN).each do |block|
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
