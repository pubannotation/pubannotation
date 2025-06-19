# frozen_string_literal: true

# It assumes that
# - annotations are already normal, and
# - documents exist in the database
class StoreAnnotationsCollection
  def initialize(project, annotations_collection, options, job = nil)
    @project = project
    @annotations_collection = annotations_collection
    @options = options
    @warnings = StoreAnnotationsCollectionWarnings.new(job)
  end

  def call
    result = aligner.call
    @warnings.concat result.warnings

    Thread.new do
      result.annotations_for_doc_collection.each do |annotations_for_doc|
        @project.pretreatment_according_to(@options, annotations_for_doc)
      end

      valid_annotations = result.get_valid_annotations(@warnings)
      InstantiateAndSaveAnnotationsCollection.call(@project, valid_annotations) if valid_annotations.present?

      @warnings.finalize
    end
  end

  private

  def aligner
    @aligner ||= initialize_aligner
  end

  def initialize_aligner
    # To find the doc for each annotation object
    result = TextAlign::AnnotationsForDocument.find_doc_for(@annotations_collection, @options[:mode] == 'skip' ? @project.id : nil)
    annotations_for_doc_collection = result.annotations_for_doc_collection
    @warnings.concat result.warnings
    @warnings.concat [{ body: "Uploading for #{result.num_skipped} documents were skipped due to existing annotations." }] if result.num_skipped > 0

    TextAlign::AlignTextInRactor.new(annotations_for_doc_collection, @options)
  end
end
