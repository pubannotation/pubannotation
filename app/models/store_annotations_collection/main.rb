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
          @warnings.concat save(result, @options, @project)
          @warnings.finalize
        end
      end
    end

    private

    def save(result, options, project)
      result.annotations_for_doc_collection.each do |annotations_for_doc|
        pretreatment_according_to options,
                                  project,
                                  annotations_for_doc.doc,
                                  annotations_for_doc.annotations
      end

      warning_messages, valid_annotations = result.valid_annotations
      InstantiateAndSaveAnnotationsCollection.call(project, valid_annotations) if valid_annotations.present?

      warning_messages
    end

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
  end
end