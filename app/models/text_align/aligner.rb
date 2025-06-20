# frozen_string_literal: true

module TextAlign
  class Aligner
    attr_reader :warnings, :num_skipped

    def initialize(annotations_collection, options, project)
      result = AnnotationsForDocument.find_doc_for(annotations_collection, options[:mode] == 'skip' ? project.id : nil)
      @align_text_in_ractor = AlignTextInRactor.new(result.annotations_for_doc_collection, options)
      @warnings = result.warnings
      @num_skipped = result.num_skipped
    end

    def call
      @align_text_in_ractor.call
    end
  end
end