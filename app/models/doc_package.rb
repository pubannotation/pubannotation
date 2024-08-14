class DocPackage
  attr_reader :docs

  def initialize(max_text_size, single_doc_processing = false)
    @max_text_size = max_text_size
    @single_doc_processing = single_doc_processing
    @docs = []
    @size = 0
  end

  def << doc
    @docs << doc
    @size += doc.body.length
  end

  def filled_with?(doc)
    return false unless @docs.any?

    @single_doc_processing || (@size + doc.body.length) > @max_text_size
  end

  def hdocs
    if document_too_large?
      doc = @docs.first
      slices = doc.get_slices(@max_text_size)
      slices.map do |slice|
        {
          text: doc.get_text(slice),
          sourcedb: doc.sourcedb,
          sourceid: doc.sourceid,
          span: slice
        }
      end
    else
      @docs.map{_1.hdoc}
    end
  end

  private

  def document_too_large?
    @docs.length == 1 && @docs.first.body.length > @max_text_size
  end
end
