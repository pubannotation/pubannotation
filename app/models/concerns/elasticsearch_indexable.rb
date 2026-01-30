# frozen_string_literal: true

# ElasticsearchIndexable concern provides queue-based Elasticsearch indexing
# for models. It replaces the synchronous elasticsearch-model callbacks with
# asynchronous Redis-based queue operations.
#
# Usage:
#   class Doc < ApplicationRecord
#     include ElasticsearchIndexable
#   end
#
# This will automatically:
#   - Queue document for indexing on create/update
#   - Queue document for deletion on destroy
#   - Provide search class methods using ES 8.x query DSL
#
module ElasticsearchIndexable
  extend ActiveSupport::Concern

  included do
    after_commit :queue_es_index, on: %i[create update]
    after_commit :queue_es_delete, on: :destroy
  end

  # Instance methods for manual ES operations

  # Queue this document for indexing
  def queue_es_index
    Elasticsearch::IndexQueue.index_doc(id)
  end

  # Queue this document for deletion
  def queue_es_delete
    Elasticsearch::IndexQueue.delete_doc(id)
  end

  # Queue embedding update for this document
  def queue_es_embedding_update
    Elasticsearch::IndexQueue.update_embedding(id)
  end

  # Index this document immediately (synchronous)
  def index_to_es!
    bulk_body = build_index_body
    ELASTICSEARCH_CLIENT.bulk(body: bulk_body, refresh: true)
  end

  # Delete this document from ES immediately (synchronous)
  def delete_from_es!
    ELASTICSEARCH_CLIENT.delete(
      index: ELASTICSEARCH_INDEX_ALIAS,
      id: id.to_s,
      routing: id.to_s,
      refresh: true
    )
  rescue Elastic::Transport::Transport::Errors::NotFound
    # Document already deleted, ignore
  end

  # Check if this document exists in ES
  def exists_in_es?
    ELASTICSEARCH_CLIENT.exists?(
      index: ELASTICSEARCH_INDEX_ALIAS,
      id: id.to_s,
      routing: id.to_s
    )
  end

  private

  def build_index_body
    [
      { index: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: id.to_s, routing: id.to_s } },
      {
        doc_project_join: { name: 'doc' },
        sourcedb: sourcedb,
        sourceid: sourceid,
        body: body,
        created_at: created_at&.iso8601,
        updated_at: updated_at&.iso8601
      }
    ]
  end

  class_methods do
    # Search documents using Elasticsearch 8.x with parent-child support
    #
    # @param keywords [String] Search query for body text
    # @param project [Project, nil] Filter by project
    # @param sourcedb [String, nil] Filter by sourcedb
    # @param page [Integer] Page number (1-based)
    # @param per [Integer] Results per page
    # @param semantic [Boolean] Use semantic/vector search (requires embeddings)
    # @return [SearchResults] Wrapped search results with pagination
    def search_by_elasticsearch(keywords, project = nil, sourcedb = nil, page = 1, per = 10, semantic: false)
      # Use hybrid search when semantic is enabled
      if semantic
        return hybrid_search(keywords, project: project, sourcedb: sourcedb, page: page, per: per)
      end

      query = build_search_query(keywords, project, sourcedb)

      response = ELASTICSEARCH_CLIENT.search(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: {
          query: query,
          highlight: {
            fields: {
              body: {}
            }
          },
          from: (page - 1) * per,
          size: per
        }
      )

      SearchResults.new(response, self, page: page, per: per)
    end

    # Build the ES query based on parameters
    def build_search_query(keywords, project = nil, sourcedb = nil)
      must_clauses = []
      filter_clauses = []

      # Text search on body
      if keywords.present?
        must_clauses << { match: { body: { query: keywords } } }
      end

      # Sourcedb filter
      if sourcedb.present?
        filter_clauses << { term: { sourcedb: sourcedb } }
      end

      # Project filter using has_child query
      if project.present?
        filter_clauses << {
          has_child: {
            type: 'project_membership',
            query: { term: { project_id: project.id } }
          }
        }
      end

      # Only search parent documents (docs), not project_membership children
      filter_clauses << {
        term: { 'doc_project_join' => 'doc' }
      }

      # Build the query
      if must_clauses.any? || filter_clauses.any?
        {
          bool: {
            must: must_clauses.presence || [{ match_all: {} }],
            filter: filter_clauses
          }
        }
      else
        { match_all: {} }
      end
    end

    # Hybrid search combining BM25 text search with vector similarity
    # Uses client-side Reciprocal Rank Fusion (RRF) to combine results
    # Works without ES Platinum license
    #
    # @param keywords [String] Search query
    # @param project [Project, nil] Filter by project
    # @param sourcedb [String, nil] Filter by sourcedb
    # @param page [Integer] Page number
    # @param per [Integer] Results per page
    # @param rrf_k [Integer] RRF constant (default 60, higher = more weight to lower ranks)
    # @return [SearchResults]
    def hybrid_search(keywords, project: nil, sourcedb: nil, page: 1, per: 10, rrf_k: 60)
      # Generate embedding for query
      query_embedding = EmbeddingService.generate(keywords)
      return search_by_elasticsearch(keywords, project, sourcedb, page, per) unless query_embedding

      # Build filters
      filter_clauses = []
      filter_clauses << { term: { 'doc_project_join' => 'doc' } }

      if sourcedb.present?
        filter_clauses << { term: { sourcedb: sourcedb } }
      end

      if project.present?
        filter_clauses << {
          has_child: {
            type: 'project_membership',
            query: { term: { project_id: project.id } }
          }
        }
      end

      # BM25 is fast (inverted index) - fetch many candidates
      # kNN is slower (vector search) - cap for performance
      bm25_candidates = 1000
      knn_candidates = [per * 5, 100].min

      # Run BM25 search
      bm25_response = ELASTICSEARCH_CLIENT.search(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: {
          query: {
            bool: {
              must: { match: { body: { query: keywords } } },
              filter: filter_clauses
            }
          },
          highlight: { fields: { body: {} } },
          _source: true,
          size: bm25_candidates
        }
      )

      # Run kNN search (no highlighting - will be added client-side in RRF merge)
      knn_response = ELASTICSEARCH_CLIENT.search(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: {
          knn: {
            field: 'body_embedding',
            query_vector: query_embedding,
            k: knn_candidates,
            num_candidates: [knn_candidates * 2, 200].min,
            filter: filter_clauses
          },
          _source: true,
          size: knn_candidates
        }
      )

      # Apply client-side RRF
      merged_response = apply_rrf(bm25_response, knn_response, keywords: keywords, page: page, per: per, k: rrf_k)

      SearchResults.new(merged_response, self, page: page, per: per)
    end

    # Pure kNN semantic search (no BM25)
    #
    # @param keywords [String] Search query
    # @param sourcedb [String, nil] Filter by sourcedb
    # @param page [Integer] Page number
    # @param per [Integer] Results per page
    # @return [SearchResults]
    def knn_search(keywords, sourcedb: nil, page: 1, per: 10)
      query_embedding = EmbeddingService.generate(keywords)
      return search_by_elasticsearch(keywords, nil, sourcedb, page, per) unless query_embedding

      # Build filters
      filter_clauses = []
      filter_clauses << { term: { 'doc_project_join' => 'doc' } }

      if sourcedb.present?
        filter_clauses << { term: { sourcedb: sourcedb } }
      end

      knn_candidates = [per * 5, 100].min

      response = ELASTICSEARCH_CLIENT.search(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: {
          knn: {
            field: 'body_embedding',
            query_vector: query_embedding,
            k: knn_candidates,
            num_candidates: [knn_candidates * 2, 200].min,
            filter: filter_clauses
          },
          _source: true,
          size: per,
          from: (page - 1) * per
        }
      )

      # Add client-side highlighting
      response['hits']['hits'].each do |hit|
        hit['highlight'] = generate_client_highlight(hit.dig('_source', 'body'), keywords)
      end

      SearchResults.new(response, self, page: page, per: per)
    end

    # Apply Reciprocal Rank Fusion to merge two search results
    # RRF score = Σ 1/(k + rank) for each result set
    #
    # @param bm25_response [Hash] BM25 search response
    # @param knn_response [Hash] kNN search response
    # @param keywords [String] Original query keywords (for client-side highlighting)
    # @param page [Integer] Page number
    # @param per [Integer] Results per page
    # @param k [Integer] RRF constant
    # @return [Hash] Merged response in ES format
    def apply_rrf(bm25_response, knn_response, keywords:, page:, per:, k: 60)
      bm25_hits = bm25_response.dig('hits', 'hits') || []
      knn_hits = knn_response.dig('hits', 'hits') || []

      # Build RRF scores and track individual scores
      rrf_scores = {}
      bm25_scores = {}
      knn_scores = {}
      bm25_ranks = {}
      knn_ranks = {}
      doc_data = {}
      has_highlight = {}

      # Process BM25 results (these have ES highlights)
      bm25_hits.each_with_index do |hit, rank|
        doc_id = hit['_id']
        rrf_scores[doc_id] ||= 0
        rrf_scores[doc_id] += 1.0 / (k + rank + 1)
        bm25_scores[doc_id] = hit['_score']
        bm25_ranks[doc_id] = rank + 1
        doc_data[doc_id] ||= hit
        has_highlight[doc_id] = hit['highlight'].present?
      end

      # Process kNN results (no ES highlights)
      knn_hits.each_with_index do |hit, rank|
        doc_id = hit['_id']
        rrf_scores[doc_id] ||= 0
        rrf_scores[doc_id] += 1.0 / (k + rank + 1)
        knn_scores[doc_id] = hit['_score']
        knn_ranks[doc_id] = rank + 1
        doc_data[doc_id] ||= hit  # Only set if not already from BM25
      end

      # Sort by RRF score
      sorted_ids = rrf_scores.sort_by { |_id, score| -score }.map(&:first)

      # Paginate
      total = sorted_ids.size
      start_idx = (page - 1) * per
      page_ids = sorted_ids[start_idx, per] || []

      # Build merged hits with all scores
      merged_hits = page_ids.map do |doc_id|
        hit = doc_data[doc_id].dup
        hit['_score'] = rrf_scores[doc_id]
        hit['_rrf_score'] = rrf_scores[doc_id]
        hit['_bm25_score'] = bm25_scores[doc_id]
        hit['_knn_score'] = knn_scores[doc_id]
        hit['_bm25_rank'] = bm25_ranks[doc_id]
        hit['_knn_rank'] = knn_ranks[doc_id]

        # Generate client-side highlight for kNN-only results
        unless has_highlight[doc_id]
          hit['highlight'] = generate_client_highlight(hit.dig('_source', 'body'), keywords)
        end

        hit
      end

      # Return in ES response format
      {
        'took' => (bm25_response['took'] || 0) + (knn_response['took'] || 0),
        'timed_out' => false,
        'hits' => {
          'total' => { 'value' => total, 'relation' => 'eq' },
          'max_score' => merged_hits.first&.dig('_score'),
          'hits' => merged_hits
        }
      }
    end

    # Generate client-side highlight by wrapping query terms in <em> tags
    # @param body [String] Document body text
    # @param keywords [String] Query keywords
    # @return [Hash] Highlight structure matching ES format
    def generate_client_highlight(body, keywords)
      return { 'body' => [] } if body.blank? || keywords.blank?

      # Strip HTML tags from body to avoid cutting in the middle of tags
      plain_body = body.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip

      # Extract individual terms from keywords (min 2 chars to avoid noise)
      terms = keywords.downcase.split(/\s+/).reject { |t| t.blank? || t.length < 2 }.uniq

      # Find a snippet around the first matching term
      snippet = nil
      match_pos = nil

      terms.each do |term|
        pos = plain_body.downcase.index(term)
        if pos && (match_pos.nil? || pos < match_pos)
          match_pos = pos
        end
      end

      if match_pos
        # Extract ~150 chars around the match, trying to start at word boundary
        start_pos = [match_pos - 50, 0].max
        end_pos = [match_pos + 100, plain_body.length].min

        # Adjust start to word boundary
        if start_pos > 0
          space_pos = plain_body.rindex(' ', start_pos + 10)
          start_pos = space_pos + 1 if space_pos && space_pos >= start_pos - 10
        end

        snippet = plain_body[start_pos...end_pos]

        # Highlight all matching terms (case-insensitive, word boundaries)
        terms.each do |term|
          snippet = snippet.gsub(/(#{Regexp.escape(term)})/i, '<em>\1</em>')
        end

        # Add ellipsis if truncated
        snippet = "...#{snippet}" if start_pos > 0
        snippet = "#{snippet}..." if end_pos < plain_body.length
      else
        # No term match found (pure semantic match) - show first 150 chars
        snippet = plain_body[0...150]
        snippet = "#{snippet}..." if plain_body.length > 150
      end

      { 'body' => [snippet] }
    end

    # Count documents in the index
    # @param project [Project, nil] Filter by project
    # @return [Integer]
    def es_count(project: nil)
      query = if project.present?
                {
                  bool: {
                    filter: [
                      { term: { 'doc_project_join' => 'doc' } },
                      {
                        has_child: {
                          type: 'project_membership',
                          query: { term: { project_id: project.id } }
                        }
                      }
                    ]
                  }
                }
              else
                { term: { 'doc_project_join' => 'doc' } }
              end

      response = ELASTICSEARCH_CLIENT.count(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: { query: query }
      )

      response['count']
    end

    # Bulk index multiple documents
    # @param doc_ids [Array<Integer>] Document IDs to index
    # @param batch_size [Integer] Batch size for bulk operations
    def bulk_index(doc_ids, batch_size: 500)
      doc_ids.each_slice(batch_size) do |batch_ids|
        Elasticsearch::IndexQueue.index_docs(batch_ids)
      end
      Elasticsearch::IndexQueue.schedule_processing
    end

    # Add project memberships in bulk
    # @param doc_ids [Array<Integer>] Document IDs
    # @param project_id [Integer] Project ID
    def bulk_add_project_membership(doc_ids, project_id)
      Elasticsearch::IndexQueue.add_project_memberships(doc_ids: doc_ids, project_id: project_id)
      Elasticsearch::IndexQueue.schedule_processing
    end

    # Remove project memberships in bulk
    # @param doc_ids [Array<Integer>] Document IDs
    # @param project_id [Integer] Project ID
    def bulk_remove_project_membership(doc_ids, project_id)
      Elasticsearch::IndexQueue.remove_project_memberships(doc_ids: doc_ids, project_id: project_id)
      Elasticsearch::IndexQueue.schedule_processing
    end
  end
end
