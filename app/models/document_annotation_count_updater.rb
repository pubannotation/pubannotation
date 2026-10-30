# frozen_string_literal: true

class DocumentAnnotationCountUpdater
  class << self
    def bulk_increment_counts_for_batch(doc_deltas)
      # Bulk update docs counters for a batch of documents
      # doc_deltas = { doc_id => {denotations: X, blocks: Y, relations: Z}, ... }
      #
      # Semantics: ALWAYS INCREMENT (docs aggregate across all projects)
      #
      # Uses VALUES with JOIN approach for efficiency with large batches (up to 500 docs)
      # Avoids 1500 WHEN clauses (3 columns × 500 docs) with CASE approach

      return if doc_deltas.empty?

      # Build VALUES list for CTE: (doc_id, denotations_delta, blocks_delta, relations_delta)
      values_list = doc_deltas.map { |doc_id, deltas|
        "(#{doc_id}, #{deltas[:denotations]}, #{deltas[:blocks]}, #{deltas[:relations]})"
      }.join(", ")

      ActiveRecord::Base.connection.execute(<<~SQL.squish)
        WITH updates(id, denotations_delta, blocks_delta, relations_delta) AS (
          VALUES #{values_list}
        )
        UPDATE docs
        SET
          denotations_num = COALESCE(docs.denotations_num, 0) + updates.denotations_delta,
          blocks_num = COALESCE(docs.blocks_num, 0) + updates.blocks_delta,
          relations_num = COALESCE(docs.relations_num, 0) + updates.relations_delta
        FROM updates
        WHERE docs.id = updates.id
      SQL
    end

  end
end
