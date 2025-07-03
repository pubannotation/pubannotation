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

    Result = Data.define(:annotations_for_doc_collection, :warnings, :num_skipped)
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

      # Find the document for the annotations.
      annotations_collection.inject(Result.new([], [], 0)) do |result, annotations|
        source = Source.new(annotations.first[:sourcedb], annotations.first[:sourceid])
        doc = Doc.where(sourcedb: source.db, sourceid: source.id).sole
        annotations_for_doc = AnnotationsForDocument.new(annotations, doc)

        if project_id_for_skip
          # skip option
          if ProjectDoc.where(project_id: project_id_for_skip, doc_id: annotations_for_doc.doc.id).pluck(:denotations_num).first == 0
            result.annotations_for_doc_collection << AnnotationsForDocument.new(annotations, doc)
          else
            result.num_skipped += 1
          end
        else
          result.annotations_for_doc_collection << annotations_for_doc
        end

        result
      rescue ActiveRecord::RecordNotFound
        result.warnings << { sourcedb: source.db, sourceid: source.id, body: 'Document does not exist.' }
        result
      rescue ActiveRecord::SoleRecordExceeded
        result.warnings << { sourcedb: source.db, sourceid: source.id, body: 'Multiple entries of the document.' }
        result
      end
    end
  end
end