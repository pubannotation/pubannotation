# frozen_string_literal: true

# It assumes that
# - annotations are already normal, and
# - documents exist in the database
class StoreAnnotationsCollection
  def initialize(project, annotations_collection, options, job = nil)
    @project = project
    @annotations_collection = annotations_collection
    @options = options
    @messages = StoreAnnotationsCollectionMessages.new(job)
  end

  def call
    result = aligner.call
    @messages.concat result.messages

    result.annotations_for_doc_collection.each do |annotations_for_doc|
      @project.pretreatment_according_to(@options, annotations_for_doc)
    end

    valid_annotations = result.annotations_for_doc_collection.reduce([]) do |valid_annotations, annotations_for_doc|
      valid_annotations + annotations_for_doc.annotations.filter.with_index do |annotation, index|
        @project.inspect_annotation @messages,
                                    annotation,
                                    index
      end
    end

    InstantiateAndSaveAnnotationsCollection.call(@project, valid_annotations) if valid_annotations.present?

    @messages.finalize
  end

  private

  def aligner
    @aligner ||= initialize_aligner
  end

  def initialize_aligner
    # To find the doc for each annotation object
    result = AnnotationsForDocument.find_doc_for(@annotations_collection, @options[:mode] == 'skip' ? id : nil)
    annotations_for_doc_collection = result.annotations_for_doc_collection
    @messages.concat result.messages
    @messages.concat [{ body: "Uploading for #{num_skipped} documents were skipped due to existing annotations." }] if result.num_skipped > 0

    AlignTextInRactor.new(annotations_for_doc_collection, @options)
  end
end