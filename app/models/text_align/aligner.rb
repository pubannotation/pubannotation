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
      annotations_for_doc_collection, num_skipped, docids_missing = AnnotationsForDocument.find_doc_for(@annotations_collection, @options[:mode] == 'skip' ? project.id : nil)
      @warnings << { body: "Uploading for #{num_skipped} documents were skipped due to existing annotations." } if num_skipped > 0
      @warnings << { sourceid: docids_missing, body: "Could not find the document(s)" } unless docids_missing.empty?

      aligner = TextAlign::AlignTextInRactor.new(annotations_for_doc_collection, @options)
      result2 = aligner.call
      @warnings.concat result2.warnings
      @warnings.finalize

      result2
    end
  end
end