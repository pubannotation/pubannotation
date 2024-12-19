class SimpleInlineTextAnnotation
  # ENTITY_TYPE_BLOCK_PATTERN matches a block of the entity type definitions.
  # Requires a blank line above the block definition.
  # Example:
  #
  # [Label1]: URL1
  # [Label2]: URL2
  ENTITY_TYPE_BLOCK_PATTERN = /(?:\A|\n{2,})((?:^\[[^\]]+\]:\s+.+\n)+)/

  def initialize(text, denotations, config = nil)
    @text = text
    @denotations = denotations
    @config = config
  end

  def to_h
    {
      text: @text,
      denotation: @denotations.map(&:to_h),
      config: @config
    }.compact
  end
end
