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
        yield doc_package.hdocs, doc_package.first_doc, nil
      rescue RuntimeError => e
        yield [], doc_package.first_doc, e
      end
    end
  end

  def hdocs_count
    @doc_packages.length
  end

  private

  def current_doc_package
    @doc_packages.last
  end
end
