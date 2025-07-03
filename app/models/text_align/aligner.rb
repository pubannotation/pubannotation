# frozen_string_literal: true

module TextAlign
  # It assumes that
  # - annotations are already normal, and
  # - documents exist in the database
  class Aligner
    def initialize(project, annotations_collection, options, job = nil)
      @project = project
      @annotations_collection = annotations_collection
      @options = options
      @warnings = Warnings.new(job)
    end

    def call
      result = AnnotationsForDocument.find_doc_for(@annotations_collection, @options[:mode] == 'skip' ? project.id : nil)
      @warnings.concat result.warnings
      @warnings << { body: "Uploading for #{result.num_skipped} documents were skipped due to existing annotations." } if result.num_skipped > 0

      aligner = TextAlign::AlignTextInRactor.new(result.annotations_for_doc_collection, @options)
      result2 = aligner.call
      @warnings.concat result2.warnings
      @warnings.finalize

      result2
    end
  end
end