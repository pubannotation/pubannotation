class DocPackage
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
      doc = first_doc
      slices = slice_document
      slices.map do |slice|
        {
          text: doc.get_text(slice),
          sourcedb: doc.sourcedb,
          sourceid: doc.sourceid,
          span: slice,
          docid: doc.id
        }
      end
    else
      @docs.map do |doc|
        {
          text: doc.body,
          sourcedb: doc.sourcedb,
          sourceid: doc.sourceid,
          docid: doc.id
        }
      end
    end
  end

  def first_doc
    @docs.first
  end

  def calculate_hdoc_count
    if @single_doc_processing && document_too_large?
      slice_document.length
    else
      1
    end
  end

  private

  def document_too_large?
    @docs.length == 1 && @docs.first.body.length > @max_text_size
  end

  def slice_document
    first_doc.get_slices(@max_text_size)
  end
end
