module TextAlign
  class AlignedResults
    attr_reader :annotations_for_doc_collection, :warnings

    def initialize(annotations_for_doc_collection, warnings = [])
      @annotations_for_doc_collection = annotations_for_doc_collection
      @warnings = warnings
    end
  end
end