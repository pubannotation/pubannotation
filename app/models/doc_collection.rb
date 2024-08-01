class DocCollection
  attr_accessor :docs
  attr_reader :size

  def initialize
    @docs = []
    @size = 0
  end

  def <<(doc)
    @docs << doc
    @size += doc.body.length
  end

  def present?
    @docs.any?
  end

  def clear
    @docs.clear
    @size = 0
  end
end
