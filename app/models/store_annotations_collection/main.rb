# frozen_string_literal: true

module StoreAnnotationsCollection
  # It assumes that
  # - annotations are already normal, and
  # - documents exist in the database
  class Main
    def initialize(project, annotations_collection, options, job = nil)
      @project = project
      @annotations_collection = annotations_collection
      @options = options
      @warnings = StoreAnnotationsCollectionWarnings.new(job)
    end

    def call
      aligner = TextAlign::Aligner.new(@annotations_collection, @options, @project)
      @warnings.concat aligner.warnings
      @warnings << { body: "Uploading for #{aligner.num_skipped} documents were skipped due to existing annotations." } if aligner.num_skipped > 0

      result = aligner.call
      @warnings.concat result.warnings

      # Use threads to start processing the next batch during asynchronous processing.
      Thread.new do
        # We are creating our own threads that Rails do not manage.
        # Explicitly releases the connection to the DB.
        ActiveRecord::Base.connection_pool.with_connection do
          @warnings.concat result.save(@options, @project)
          @warnings.finalize
        end
      end
    end
  end
end