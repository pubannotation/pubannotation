# frozen_string_literal: true

module TextAlign
  class AlignedResults
    attr_reader :annotations_for_doc_collection, :warnings

    def initialize(annotations_for_doc_collection, warnings = [])
      @annotations_for_doc_collection = annotations_for_doc_collection
      @warnings = warnings
    end

    def save(project, options)
      @annotations_for_doc_collection.each do |annotations_for_doc|
        project.pretreatment_according_to options,
                                          annotations_for_doc.doc,
                                          annotations_for_doc.annotations
      end

      warning_messages, valid_annotations = self.valid_annotations
      project.instantiate_and_save_annotations_collection(valid_annotations) if valid_annotations.present?

      warning_messages
    end

    private


    def valid_annotations
      warnings = []
      results = @annotations_for_doc_collection.reduce([]) do |results, annotations_for_doc|
        warnings_messages, valid_annotations = annotations_for_doc.valid_annotations
        warnings.concat(warnings_messages)
        results.concat valid_annotations
      end

      [warnings, results]
    end
  end
end