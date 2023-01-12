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
    having_denotations_or_blocks.map { |annotation| Aligner.new(annotation[:text], annotation[:denotations], annotation[:blocks]) }
  end

  def self.find_doc_for(annotations_collection)
    annotations_collection.inject([[], []]) do |result, annotations|
      annotations_for_doc_collection, messages = result

      source = DocumentSource.new(annotations)
      doc = Doc.where(sourcedb: source.db, sourceid: source.id).sole
      annotations_for_doc_collection << AnnotationsForDocument.new(annotations, doc)
      result
    rescue ActiveRecord::RecordNotFound
      messages << { sourcedb: source.db, sourceid: source.id, body: 'Document does not exist.' }
      result
    rescue ActiveRecord::SoleRecordExceeded
      messages << { sourcedb: source.db, sourceid: source.id, body: 'Multiple entries of the document.' }
      result
    end
  end

  class Aligner
    def initialize(text, denotations, blocks)
      @text = text
      @denotations = denotations || []
      @blocks = blocks || []
    end

    def align(aligner)
      aligner.align(@text, @denotations + @blocks)

      AlignedAnnotation.new aligner.transform_hdenotations(@denotations),
                            aligner.transform_hdenotations(@blocks),
                            aligner.lost_annotations,
                            aligner.lost_annotations.present? ? aligner.block_alignment : nil

    end
  end

  class AlignedAnnotation
    attr_reader :denotations, :blocks, :lost_annotations, :block_alignments, :error_message

    def initialize(denotations, blocks, lost_annotations, block_alignments, error_message = nil)
      @denotations = denotations
      @blocks = blocks
      @lost_annotations = lost_annotations
      @block_alignments = block_alignments
      @error_message = error_message
    end
  end
end
