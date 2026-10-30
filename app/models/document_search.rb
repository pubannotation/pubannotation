# frozen_string_literal: true

class DocumentSearch
  class << self
    def search_by_active_record(page, per, project = nil, sourcedb = nil,
                              sort_key = nil, sort_direction = nil, is_randomize = false)
      docs = Doc.all
      docs = docs.joins(:projects).where(projects: { id: project.id }) if project.present?
      docs = docs.where(sourcedb: sourcedb) if sourcedb.present?

      sort_order = if sort_key.present? && sort_direction.present?
                     "#{sort_key} #{sort_direction}"
                   else
                     default_sort_order_for project
                   end
      sort_order = [sort_order, Arel.sql('random()')] if is_randomize

      docs.order(sort_order).simple_paginate(page, per)
    end

    def search_by_term(user, base_project_name, terms, predicates, projects, page, per)
      base_project = Project.accessible(user).find_by!(name: base_project_name) if base_project_name.present?
      docs = base_project.present? ? base_project.docs : Doc.all

      if terms.present?
        docs = docs.with_terms terms,
                               user,
                               predicates,
                               projects
      end

      docs.select('sourcedb', 'sourceid')
          .simple_paginate(page, per)
          .map(&:to_list_hash)
    end

    # default sort order
    #DefaultSort = [['sourceid', 'ASC']]
    def default_sort_order_for(project)
      return "sourceid ASC" if project&.small?

      ''
    end

    # Search documents using Elasticsearch 8.x
    # This method signature is kept for backward compatibility with existing code
    #
    # @param keywords [String] Search query
    # @param project [Project, nil] Filter by project
    # @param sourcedb [String, nil] Filter by sourcedb
    # @param page [Integer] Page number (1-based)
    # @param per [Integer] Results per page
    # @param semantic [Boolean] Use hybrid semantic search
    # @return [SearchResults] Wrapped search results
    def search_by_elasticsearch(keywords, project, sourcedb, page, per, semantic: false)
      return SearchResults.new({ 'hits' => { 'hits' => [], 'total' => 0 } }, Doc, page: page, per: per) if keywords.blank?

      if semantic
        hybrid_search(keywords, project: project, sourcedb: sourcedb, page: page, per: per)
      else
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

        SearchResults.new(response, Doc, page: page, per: per)
      end
    rescue => e
      Rails.logger.error "[ES Search] Error: #{e.message}"
      # Return empty results on ES errors to avoid breaking the UI
      SearchResults.new({ 'hits' => { 'hits' => [], 'total' => 0 } }, Doc, page: page, per: per)
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

      SearchResults.new(merged_response, Doc, page: page, per: per)
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

      SearchResults.new(response, Doc, page: page, per: per)
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
  end
end
