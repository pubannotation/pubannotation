# frozen_string_literal: true

class AnnotationsForDocument
  attr_reader :annotations, :doc
  def initialize(annotations, doc)
    @annotations = annotations
    @doc = doc
  end

  def ref_text
    doc&.original_body || doc.body
  end

  def having_denotations_or_blocks
    @having_denotations_or_blocks ||= annotations.filter {|a| a[:denotations].present? || a[:blocks].present? }
  end

  def aligners
    Aligners.new ref_text,
                 having_denotations_or_blocks
  end

  Result = Data.define(:annotations_for_doc_collection, :messages)

  def self.find_doc_for(annotations_collection)
    # Standardize annotations into arrays.
    annotations_collection = annotations_collection.map { |annotations|
      if annotations.is_a? Array
        annotations
      else
        [annotations]
      end
    }

    # Find the document for the annotations.
    annotations_collection.inject(Result.new([], [])) do |result, annotations|
      source = DocumentSource.new(annotations)
      doc = Doc.where(sourcedb: source.db, sourceid: source.id).sole
      result.annotations_for_doc_collection << AnnotationsForDocument.new(annotations, doc)
      result
    rescue ActiveRecord::RecordNotFound
      result.messages << { sourcedb: source.db, sourceid: source.id, body: 'Document does not exist.' }
      result
    rescue ActiveRecord::SoleRecordExceeded
      result.messages << { sourcedb: source.db, sourceid: source.id, body: 'Multiple entries of the document.' }
      result
    end
  end

  def self.num_skipped(project_id, annotations_for_doc_collection)
    num_annotations_for_doc = annotations_for_doc_collection.count

    annotations_for_doc_collection.select! do |annotations_for_doc|
      ProjectDoc.where(project_id: project_id, doc_id: annotations_for_doc.doc.id).pluck(:denotations_num).first == 0
    end
    num_annotations_for_doc - annotations_for_doc_collection.count
  end
end
