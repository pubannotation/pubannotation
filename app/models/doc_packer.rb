class DocPacker
  def initialize(annotator, encoding: nil)
    @max_text_size = annotator.find_or_define_max_text_size
    @single_doc_processing = annotator.single_doc_processing?
    @doc_packages = [DocPackage.new(@max_text_size, @single_doc_processing)]
    @encoding = encoding
  end

  def << doc_id
    doc = Doc.find_by!(id: doc_id)
    doc.set_ascii_body if @encoding == 'ascii'

    if current_doc_package.filled_with?(doc)
      @doc_packages << DocPackage.new(@max_text_size, @single_doc_processing)
    end

    current_doc_package << doc
  end

  def each
    @doc_packages.each do |doc_package|
      begin
        if @single_doc_processing
          process_single_doc(doc_package) do |annotation_request|
            yield annotation_request
          end
        else
          process_multiple_docs(doc_package) do |annotation_request|
            yield annotation_request
          end
        end
      rescue RuntimeError => e
        yield AnnotationRequest.new(hdocs: [doc_package.first_doc.hdoc], error: e)
      end
    end
  end

  def request_count
    @doc_packages.map(&:calculate_hdoc_count).sum
  end

  private

  def process_single_doc(doc_package)
    doc_package.hdocs.each_with_index do |hdoc, i|
      if i == 0 && hdoc[:span].present?
        yield AnnotationRequest.new(hdocs: [hdoc], doc: doc_package.first_doc, slice_count: doc_package.hdocs.length)
      else
        yield AnnotationRequest.new(hdocs: [hdoc], doc: doc_package.first_doc)
      end
    end
  end

  def process_multiple_docs(doc_package)
    if doc_package.hdocs.any? { _1.key?(:span) }
      yield AnnotationRequest.new(hdocs: doc_package.hdocs, doc: doc_package.first_doc, slice_count: doc_package.hdocs.length)
    else
      yield AnnotationRequest.new(hdocs: doc_package.hdocs, doc: doc_package.first_doc)
    end
  end

  def current_doc_package
    @doc_packages.last
  end
end
