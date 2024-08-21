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
          doc_package.hdocs.each_with_index do |hdoc, i|
            if i == 0 && hdoc[:span].present?
              yield [hdoc], doc_package.first_doc, nil, doc_package.hdocs.length
            else
              yield [hdoc], doc_package.first_doc, nil
            end
          end
        else
          if doc_package.hdocs.any? { _1.key?(:span) }
            yield doc_package.hdocs, doc_package.first_doc, nil, doc_package.hdocs.length
          else
            yield doc_package.hdocs, doc_package.first_doc, nil
          end
        end
      rescue RuntimeError => e
        yield [], doc_package.first_doc, e
      end
    end
  end

  def hdocs_count
    @doc_packages.map(&:calculate_hdoc_count).sum
  end

  private

  def current_doc_package
    @doc_packages.last
  end
end
