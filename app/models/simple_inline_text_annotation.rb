class SimpleInlineTextAnnotation
  # ENTITY_TYPE_BLOCK_PATTERN matches a block of the entity type definitions.
  # Requires a blank line above the block definition.
  # Example:
  #
  # [Label1]: URL1
  # [Label2]: URL2
  ENTITY_TYPE_BLOCK_PATTERN = /(?:\A|\n{2,})((?:^\[[^\]]+\]:\s+.+\n)+)/

  # ESCAPE_PATTERN matches a backslash (\) preceding two consecutive pairs of square brackets.
  # Example: \[This is a part of][original text]
  ESCAPE_PATTERN = /\\(?=\[[^\]]+\]\[[^\]]+\])/

  def initialize(text, denotations, entity_type_collection)
    @text = text
    @denotations = denotations
    @entity_type_collection = entity_type_collection
  end

  def self.parse(source)
    SimpleInlineTextAnnotation::Parser.new(source).parse
  end

  def to_h
    {
      text: text_without_escape_backslash(@text),
      denotation: @denotations.map(&:to_h),
      config: config
    }.compact
  end

  private

  def text_without_escape_backslash(text)
    # Remove backslashes used to escape inline annotation format.
    # For example, `\[Elon Musk][Person]` is treated as plain text
    # rather than an annotation. This method removes the leading
    # backslash and keeps the text as `[Elon Musk][Person]`.

    text.gsub(ESCAPE_PATTERN, '')
  end

  def config
    return nil unless @entity_type_collection.any?

    { "entity types": @entity_type_collection.to_config }
  end
end
