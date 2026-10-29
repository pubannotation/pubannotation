module TextNormalizable
  # Puts text on one line: line breaks, tabs and runs of spaces as one space, and none around it.
  def self.normalize_inline_text(text)
    return nil unless text

    text.gsub(/\r\n|[\r\n\t]/, ' ').gsub(/ {2,}/, ' ').strip
  end
end
