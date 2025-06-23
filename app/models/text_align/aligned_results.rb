# frozen_string_literal: true

module TextAlign
  class AlignedResults
    attr_reader :annotations_for_doc_collection, :warnings

    def initialize(annotations_for_doc_collection, warnings = [])
      @annotations_for_doc_collection = annotations_for_doc_collection
      @warnings = warnings
    end

    def save(options, project)
      @annotations_for_doc_collection.each do |annotations_for_doc|
        pretreatment_according_to options,
                                  project,
                                  annotations_for_doc.doc,
                                  annotations_for_doc.annotations
      end

      warning_messages, valid_annotations = self.valid_annotations
      project.instantiate_and_save_annotations_collection(valid_annotations) if valid_annotations.present?

      warning_messages
    end

    private

    def pretreatment_according_to(options, project, document, annotations)
      if options[:mode] == 'replace'
        project.delete_doc_annotations document
      else
        case options[:mode]
        when 'add'
          annotations.each { |a| project.reid_annotations!(a, document) }
        when 'merge'
          annotations.each { |a| project.reid_annotations!(a, document) }
          base_annotations = document.hannotations(project, nil, nil)
          annotations.each { |a| AnnotationUtils.prepare_annotations_for_merging!(a, base_annotations) }
        end
      end
    end

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