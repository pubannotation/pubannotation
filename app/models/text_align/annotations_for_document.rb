# frozen_string_literal: true

module TextAlign
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

    def valid_annotations
      warning_messages = []

      results = annotations.reduce([]) do |valid_annotations, annotation|
        dangling_references = TextAlign::DanglingReferenceFinder.call(
          annotation[:denotations] || [],
          annotation[:blocks] || [],
          annotation[:relations] || [],
          annotation[:attributes] || []
        )
        if dangling_references.present?
          warning_messages << {
            sourcedb: annotation[:sourcedb],
            sourceid: annotation[:sourceid],
            body: "After alignment, #{dangling_references.length} dangling references were found: #{dangling_references.join ', '}."
          }
          valid_annotations
        else
          valid_annotations << annotation
        end
      end

      [warning_messages, results]
    end

    Result = Data.define(:annotations_for_doc_collection, :num_skipped, :num_missing)
    Source = Data.define(:db, :id)

    def self.find_doc_for(annotations_collection, project_id_for_skip)
      # Standardize annotations into arrays.
      annotations_collection = annotations_collection.map { |annotations|
        if annotations.is_a? Array
          annotations
        else
          [annotations]
        end
      }

      annotations_for_doc_collection = []
      num_skipped = 0
      docids_missing = []
      num_missing = 0

      # Find the document for the annotations.
      annotations_collection.each do |annotations|
        source = Source.new(annotations.first[:sourcedb], annotations.first[:sourceid])
        doc = Doc.where(sourcedb: source.db, sourceid: source.id).sole
        annotations_for_doc = AnnotationsForDocument.new(annotations, doc)

        if project_id_for_skip
          # skip option
          if ProjectDoc.where(project_id: project_id_for_skip, doc_id: annotations_for_doc.doc.id).pluck(:denotations_num).first == 0
            annotations_for_doc_collection << AnnotationsForDocument.new(annotations, doc)
          else
            num_skipped += 1
          end
        else
          annotations_for_doc_collection << annotations_for_doc
        end

      rescue ActiveRecord::RecordNotFound
        docids_missing << source.id
      rescue ActiveRecord::SoleRecordExceeded
        raise ActiveRecord::SoleRecordExceeded, "Multiple entries of the same document: #{source.db}:#{source.id}."
      end

      [annotations_for_doc_collection, num_skipped, docids_missing.uniq]
    end
  end
end