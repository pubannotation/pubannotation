# frozen_string_literal: true

module TextAlign
  class AlignedResults
    attr_reader :annotations_for_doc_collection, :warnings

    def initialize(annotations_for_doc_collection, warnings = [])
      @annotations_for_doc_collection = annotations_for_doc_collection
      @warnings = warnings
    end

    def get_valid_annotations(warnings)
      @annotations_for_doc_collection.reduce([]) do |valid_annotations, annotations_for_doc|
        valid_annotations.concat(
          annotations_for_doc.annotations.filter do |annotation|
            warning = AnnotationInspector.call(
              annotation[:sourcedb],
              annotation[:sourceid],
              annotation[:denotations] || [],
              annotation[:blocks] || [],
              annotation[:relations] || [],
              annotation[:attributes] || []
            )
            if warning
              warnings << warning
              false
            else
              true
            end
          end
        )
      end
    end
  end
end