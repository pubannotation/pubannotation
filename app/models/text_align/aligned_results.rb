# frozen_string_literal: true

module TextAlign
  class AlignedResults
    attr_reader :annotations_for_doc_collection, :warnings

    def initialize(annotations_for_doc_collection, warnings = [])
      @annotations_for_doc_collection = annotations_for_doc_collection
      @warnings = warnings
    end

    def get_valid_annotations(warnings)
      @annotations_for_doc_collection.reduce([]) do |results, annotations_for_doc|
        warnings_messages, valid_annotations = annotations_for_doc.valid_annotations
        warnings.concat(warnings_messages)
        results.concat valid_annotations
      end
    end
  end
end