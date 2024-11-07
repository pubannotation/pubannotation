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
  end

  private

  def aligner
    @aligner ||= initialize_aligner
  end

  def initialize_aligner
    # To find the doc for each annotation object
    result = AnnotationsForDocument.find_doc_for(@annotations_collection, @options[:mode] == 'skip' ? @project.id : nil)
    annotations_for_doc_collection = result.annotations_for_doc_collection
    @warnings.concat result.warnings
    @warnings.concat [{ body: "Uploading for #{result.num_skipped} documents were skipped due to existing annotations." }] if result.num_skipped > 0

    AlignTextInRactor.new(annotations_for_doc_collection, @options)
  end

  def inspect_annotations(messages, annotation, index)
    denotations = annotation[:denotations] || []
    blocks = annotation[:blocks] || []
    relations = annotation[:relations] || []
    attributes = annotation[:attributes] || []

    sourcedb = annotation[:sourcedb]
    sourceid = annotation[:sourceid]

    db_ids = denotations.map { |d| d[:id] } + blocks.map { |b| b[:id] }
    dbr_ids = db_ids + relations.map { |d| d[:id] }

    dangling_references = if denotations.present? || blocks.present?
      relations.map { |r| r[:subj] }.filter { |subj| !db_ids.include? subj } +
      relations.map { |r| r[:obj] }.filter { |obj| !db_ids.include? obj } +
      attributes.map { |a| a[:subj] }.filter { |obj| !dbr_ids.include? obj }
    else
      _dangling_references = []
      if relations.present?
        _dangling_references += relations.map { |r| r[:subj] } + relations.map { |r| r[:obj] }

        r_ids = relations.map { |d| d[:id] }
        _dangling_references += attributes.map { |a| a[:subj] }.filter { |obj| !r_ids.include? obj }
      else
        _dangling_references += attributes.map { |a| a[:subj] }
      end
    end

    if dangling_references.present?
      messages.concat [{
                         sourcedb: sourcedb,
                         sourceid: sourceid,
                         body: "After alignment, #{dangling_references.length} dangling references were found: #{dangling_references.join ", "}."
                       }]
      false
    else
      true
    end
  end
end
