class SimpleInlineTextAnnotation
  # ENTITY_TYPE_PATTERN matches a pair of square brackets which is followed by a colon and URL.
  # Similar to Markdown, this also matches when there is text enclosed in "" or '' after the URL.
  # Match example:
  #  - [Label]: URL
  #  - [Label]: URL "text"
  ENTITY_TYPE_PATTERN = /^\s*\[([^\]]+)\]:\s+(\S+)(?:\s+(?:"[^"]*"|'[^']*'))?\s*$/

  # ENTITY_TYPE_BLOCK_PATTERN matches a block of the entity type definitions.
  # Requires a blank line above the block definition.
  ENTITY_TYPE_BLOCK_PATTERN = /(?:\A|\n\s*\n)((?:#{ENTITY_TYPE_PATTERN}(?:\n|$))+)/

  # ESCAPE_PATTERN matches a backslash (\) preceding two consecutive pairs of square brackets.
  # Example: \[This is a part of][original text]
  ESCAPE_PATTERN = /\\(?=\[[^\]]+\]\[[^\]]+\])/

  def initialize(text, denotations, entity_type_collection)
    @text = text
    @denotations = denotations
    @entity_type_collection = entity_type_collection
  end

  def self.parse(source)
    result = SimpleInlineTextAnnotation::Parser.new(source).parse
    result.to_h
  end

  def self.generate(source)
    SimpleInlineTextAnnotation::Generator.new(source).generate
  end

  def to_h
    {
      text: format_text(@text),
      denotations: @denotations.map(&:to_h),
      config: config
    }.compact
  end

  private

  def format_text(text)
    result = remove_escape_backslash_from(text)
    result = reduce_consecutive_newlines_from(result)

    result
  end

  # Remove backslashes used to escape inline annotation format.
  # For example, `\[Elon Musk][Person]` is treated as plain text
  # rather than an annotation. This method removes the leading
  # backslash and keeps the text as `[Elon Musk][Person]`.
  def remove_escape_backslash_from(text)
    text.gsub(ESCAPE_PATTERN, '')
  end

  # Reduce consecutive newlines to a single newline.
  def reduce_consecutive_newlines_from(text)
    text.gsub(/\n{2,}/, "\n\n")
  end

  def config
    return nil unless @entity_type_collection.any?

    { "entity types": @entity_type_collection.to_config }
  end
end
