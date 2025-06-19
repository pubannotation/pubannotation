module TextAlign
  class AlignedResults
    attr_reader :annotations_for_doc_collection, :warnings

    def initialize(annotations_for_doc_collection, warnings = [])
      @annotations_for_doc_collection = annotations_for_doc_collection
      @warnings = warnings
    end

    def get_valid_annotations(warnings)
      @annotations_for_doc_collection.reduce([]) do |valid_annotations, annotations_for_doc|
        valid_annotations + annotations_for_doc.annotations.filter do |annotation|
          inspect_annotations warnings,
                              annotation
        end
      end
    end

    private

    def inspect_annotations(messages, annotation)
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
end