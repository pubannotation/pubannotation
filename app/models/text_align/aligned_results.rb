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
            dangling_references = DanglingReferenceFinder.call(
              annotation[:denotations] || [],
              annotation[:blocks] || [],
              annotation[:relations] || [],
              annotation[:attributes] || []
            )
            if dangling_references.present?
              warnings << {
                sourcedb: annotation[:sourcedb],
                sourceid: annotation[:sourceid],
                body: "After alignment, #{dangling_references.length} dangling references were found: #{dangling_references.join ", "}."
              }
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