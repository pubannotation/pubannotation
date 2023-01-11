# frozen_string_literal: true

class AnnotationWithDocument
  attr_reader :annotations, :doc
  def initialize(annotations, doc)
    @annotations = annotations
    @doc = doc
  end

  def ref_text
    doc&.original_body || doc.body
  end

  def targets
    @targets ||= annotations.filter {|a| a[:denotations].present? || a[:blocks].present? }
  end

  def self.find_doc_for(annotations_collection)
    annotations_collection.inject([[], []]) do |result, annotations|
      annotations_for_doc_collection, messages = result

      source = DocumentSource.new(annotations)
      doc = Doc.where(sourcedb: source.db, sourceid: source.id).sole
      annotations_for_doc_collection << AnnotationWithDocument.new(annotations, doc)
      result
    rescue ActiveRecord::RecordNotFound
      messages << { sourcedb: source.db, sourceid: source.id, body: 'Document does not exist.' }
      result
    rescue ActiveRecord::SoleRecordExceeded
      messages << { sourcedb: source.db, sourceid: source.id, body: 'Multiple entries of the document.' }
      result
    end
  end
end
