# frozen_string_literal: true

module AnnotationInspector
  def self.call(sourcedb, sourceid, denotations, blocks, relations, attributes)
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
      {
        sourcedb:,
        sourceid:,
        body: "After alignment, #{dangling_references.length} dangling references were found: #{dangling_references.join ", "}."
      }
    end
  end
end