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

    result.annotations_for_doc_collection.each do |annotations_for_doc|
      @project.pretreatment_according_to(@options, annotations_for_doc)
    end

    valid_annotations = result.annotations_for_doc_collection.reduce([]) do |valid_annotations, annotations_for_doc|
      valid_annotations + annotations_for_doc.annotations.filter.with_index do |annotation, index|
        inspect_annotations @warnings,
                            annotation,
                            index
      end
    end

    InstantiateAndSaveAnnotationsCollection.call(@project, valid_annotations) if valid_annotations.present?

    @warnings.finalize
  end

  private

  def aligner
    @aligner ||= initialize_aligner
  end

  def initialize_aligner
    # To find the doc for each annotation object
    result = AnnotationsForDocument.find_doc_for(@annotations_collection, @options[:mode] == 'skip' ? id : nil)
    annotations_for_doc_collection = result.annotations_for_doc_collection
    @warnings.concat result.warnings
    @warnings.concat [{ body: "Uploading for #{num_skipped} documents were skipped due to existing annotations." }] if result.num_skipped > 0

    AlignTextInRactor.new(annotations_for_doc_collection, @options)
  end

  def inspect_annotations(messages, annotation, index)
    denotations = annotation[:denotations]
    attributes = annotation[:attributes]
    sourcedb = annotation[:sourcedb]
    sourceid = annotation[:sourceid]

    if denotations && attributes
      denotation_ids = denotations.map { |d| d[:id] }
      subject_less_attributes = attributes.map { |a| a[:subj] }
                                          .filter { |subj| !denotation_ids.include? subj }
      if subject_less_attributes.present?
        messages.concat [{
                           sourcedb: sourcedb,
                           sourceid: sourceid,
                           body: "After alignment adjustment of the denotations, annotations with an index of #{index} does not have denotations #{subject_less_attributes.join ", "} that is the subject of attributes."
                         }]
        false
      else
        true
      end
    else
      messages.concat [{
                         sourcedb: sourcedb,
                         sourceid: sourceid,
                         body: "After alignment adjustment of the denotations, annotations with an index of #{index} have no denotation."
                       }]
      false
    end
  end


end