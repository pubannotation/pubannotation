# frozen_string_literal: true

class DocCountsUpdater
  class << self
    # Shared method to bulk update annotation counts for docs table
    # @param doc_ids [Array<Integer>, nil] Optional array of doc IDs to update. If nil, updates all docs.
    def update(doc_ids = nil)
      return if doc_ids&.empty?

      if doc_ids.nil?
        # Update ALL docs - use unfiltered subqueries
        bulk_update_all_docs_counts
      elsif doc_ids.size < 5000
        # Small batch - use filtered subqueries with IN clause for best performance
        bulk_update_with_in_clause(doc_ids)
      elsif doc_ids.size < 100000
        # Medium batch - process in chunks to avoid query size limits
        doc_ids.each_slice(5000) do |batch|
          bulk_update_with_in_clause(batch)
        end
      else
        # Large batch (100k+ docs) - use temp table to avoid query size limits
        bulk_update_with_temp_table(doc_ids)
      end
    end

    def increment(doc_deltas)
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

    private

    def bulk_update_all_docs_counts
      # Update all docs without filtering - used when doc_ids is nil
      # Note: projects_num is maintained incrementally and not updated here
      ActiveRecord::Base.connection.update <<~SQL.squish
        UPDATE docs
        SET
          denotations_num = COALESCE(d.cnt, 0),
          blocks_num = COALESCE(b.cnt, 0),
          relations_num = COALESCE(r.cnt, 0)
        FROM
          docs doc_list
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM denotations GROUP BY doc_id) d ON doc_list.id = d.doc_id
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM blocks GROUP BY doc_id) b ON doc_list.id = b.doc_id
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM relations GROUP BY doc_id) r ON doc_list.id = r.doc_id
        WHERE docs.id = doc_list.id
      SQL
    end

    def bulk_update_with_in_clause(doc_ids)
      # Update specific docs - filter subqueries for performance
      # This avoids full table scans by restricting subqueries to only relevant doc_ids
      # Note: projects_num is maintained incrementally and not updated here
      doc_ids_str = doc_ids.join(',')

      ActiveRecord::Base.connection.update <<~SQL.squish
        UPDATE docs
        SET
          denotations_num = COALESCE(d.cnt, 0),
          blocks_num = COALESCE(b.cnt, 0),
          relations_num = COALESCE(r.cnt, 0)
        FROM
          docs doc_list
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM denotations WHERE doc_id IN (#{doc_ids_str}) GROUP BY doc_id) d ON doc_list.id = d.doc_id
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM blocks WHERE doc_id IN (#{doc_ids_str}) GROUP BY doc_id) b ON doc_list.id = b.doc_id
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM relations WHERE doc_id IN (#{doc_ids_str}) GROUP BY doc_id) r ON doc_list.id = r.doc_id
        WHERE docs.id = doc_list.id AND docs.id IN (#{doc_ids_str})
      SQL
    end

    def bulk_update_with_temp_table(doc_ids)
      # For very large batches, use a temp table to avoid query size limits
      # This is the most efficient approach for 100k+ documents
      conn = ActiveRecord::Base.connection

      conn.execute("CREATE TEMP TABLE IF NOT EXISTS temp_doc_ids_for_count_update (doc_id INTEGER PRIMARY KEY) ON COMMIT DROP")

      # Insert doc_ids in batches to avoid memory issues
      doc_ids.each_slice(10000) do |batch|
        values = batch.map { |id| "(#{id})" }.join(',')
        conn.execute("INSERT INTO temp_doc_ids_for_count_update (doc_id) VALUES #{values} ON CONFLICT DO NOTHING")
      end

      # Perform the update using the temp table
      # Note: projects_num is maintained incrementally and not updated here
      conn.update <<~SQL.squish
        UPDATE docs
        SET
          denotations_num = COALESCE(d.cnt, 0),
          blocks_num = COALESCE(b.cnt, 0),
          relations_num = COALESCE(r.cnt, 0)
        FROM
          temp_doc_ids_for_count_update target
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM denotations WHERE doc_id IN (SELECT doc_id FROM temp_doc_ids_for_count_update) GROUP BY doc_id) d ON target.doc_id = d.doc_id
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM blocks WHERE doc_id IN (SELECT doc_id FROM temp_doc_ids_for_count_update) GROUP BY doc_id) b ON target.doc_id = b.doc_id
          LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM relations WHERE doc_id IN (SELECT doc_id FROM temp_doc_ids_for_count_update) GROUP BY doc_id) r ON target.doc_id = r.doc_id
        WHERE docs.id = target.doc_id
      SQL

      # Temp table is automatically dropped on commit due to ON COMMIT DROP
    end
  end
end
