# frozen_string_literal: true

# Search comparison tasks for evaluating BM25 vs vector search
#
# Usage:
#   rake search:compare[query]           # Compare BM25 vs kNN for a query
#   rake search:compare_batch            # Run predefined test queries

namespace :search do
  desc 'Compare BM25 and kNN search results for a query'
  task :compare, [:query] => :environment do |_t, args|
    query = args[:query] || 'p53 tumor suppressor'

    puts "\n" + "=" * 80
    puts "SEARCH COMPARISON: #{query}"
    puts "=" * 80

    # BM25 Search
    puts "\n### BM25 (Keyword) Search ###"
    bm25_start = Time.current
    bm25_results = bm25_search(query, 10)
    bm25_time = Time.current - bm25_start

    puts "Time: #{(bm25_time * 1000).round(1)}ms"
    puts "Total hits: #{bm25_results[:total]}"
    puts "\nTop 10 results:"
    bm25_results[:hits].each_with_index do |hit, idx|
      puts "  #{idx + 1}. [#{hit[:score].round(3)}] #{hit[:sourcedb]}:#{hit[:sourceid]}"
      puts "     #{truncate_text(hit[:body], 100)}"
    end

    # kNN (Vector) Search
    puts "\n### kNN (Vector) Search ###"
    knn_start = Time.current
    knn_results = knn_search(query, 10)
    knn_time = Time.current - knn_start

    if knn_results[:error]
      puts "Error: #{knn_results[:error]}"
    else
      puts "Time: #{(knn_time * 1000).round(1)}ms"
      puts "Total hits: #{knn_results[:total]}"
      puts "\nTop 10 results:"
      knn_results[:hits].each_with_index do |hit, idx|
        puts "  #{idx + 1}. [#{hit[:score].round(3)}] #{hit[:sourcedb]}:#{hit[:sourceid]}"
        puts "     #{truncate_text(hit[:body], 100)}"
      end
    end

    # Hybrid Search (client-side RRF)
    puts "\n### Hybrid Search (BM25 + kNN with RRF) ###"
    hybrid_start = Time.current
    hybrid_results = Doc.hybrid_search(query, page: 1, per: 10)
    hybrid_time = Time.current - hybrid_start

    puts "Time: #{(hybrid_time * 1000).round(1)}ms"
    puts "Total hits: #{hybrid_results.total}"
    puts "\nTop 10 results:"
    hybrid_results.each_with_index do |hit, idx|
      puts "  #{idx + 1}. [#{hit.score&.round(4)}] #{hit.sourcedb}:#{hit.sourceid}"
      puts "     #{truncate_text(hit.body, 100)}"
    end

    # Comparison
    puts "\n### Comparison ###"
    bm25_ids = bm25_results[:hits].map { |h| h[:id] }
    knn_ids = knn_results[:hits]&.map { |h| h[:id] } || []
    hybrid_ids = hybrid_results.map { |h| h.id.to_i }

    puts "\nOverlap Analysis:"
    puts "  BM25 ∩ kNN:    #{(bm25_ids & knn_ids).size}/10"
    puts "  BM25 ∩ Hybrid: #{(bm25_ids & hybrid_ids).size}/10"
    puts "  kNN ∩ Hybrid:  #{(knn_ids & hybrid_ids).size}/10"
    puts "  All three:     #{(bm25_ids & knn_ids & hybrid_ids).size}/10"

    puts "\nUnique to each method:"
    puts "  BM25 only:   #{(bm25_ids - knn_ids - hybrid_ids).size}"
    puts "  kNN only:    #{(knn_ids - bm25_ids - hybrid_ids).size}"
    puts "  Hybrid only: #{(hybrid_ids - bm25_ids - knn_ids).size}"

    puts "\nHybrid ranking (showing source contributions):"
    hybrid_ids.first(10).each_with_index do |id, idx|
      bm25_rank = bm25_ids.index(id)&.+(1) || '-'
      knn_rank = knn_ids.index(id)&.+(1) || '-'
      puts "  #{idx + 1}. Doc #{id}: BM25=##{bm25_rank}, kNN=##{knn_rank}"
    end

    puts "\n"
  end

  desc 'Run comparison on predefined biomedical queries'
  task compare_batch: :environment do
    queries = [
      # Exact term queries (BM25 should excel)
      'BRCA1 mutation',
      'COVID-19 vaccine',
      'insulin resistance',

      # Semantic/conceptual queries (kNN might find related concepts)
      'cancer treatment side effects',
      'heart disease prevention',
      'gene therapy applications',

      # Synonym tests (kNN should find synonyms)
      'tumor suppressor',      # Should find p53, Rb, etc.
      'diabetes mellitus',     # Should find related metabolic terms
      'myocardial infarction', # Should find heart attack, cardiac
    ]

    queries.each do |query|
      Rake::Task['search:compare'].reenable
      Rake::Task['search:compare'].invoke(query)
    end
  end

  desc 'Test semantic similarity - find documents similar to a given doc'
  task :similar, [:doc_id] => :environment do |_t, args|
    doc_id = args[:doc_id]&.to_i
    raise "Doc ID required: rake search:similar[DOC_ID]" unless doc_id

    doc = Doc.find_by(id: doc_id)
    raise "Doc not found: #{doc_id}" unless doc

    puts "\n" + "=" * 80
    puts "SIMILAR DOCUMENTS TO: #{doc.sourcedb}:#{doc.sourceid}"
    puts "=" * 80
    puts "\nSource document body:"
    puts truncate_text(doc.body, 300)

    # Get the document's embedding from ES
    response = ELASTICSEARCH_CLIENT.get(
      index: ELASTICSEARCH_INDEX_ALIAS,
      id: doc_id.to_s,
      routing: doc_id.to_s
    )

    embedding = response.dig('_source', 'body_embedding')
    unless embedding
      puts "\nError: Document has no embedding"
      exit 1
    end

    # Find similar documents using kNN
    puts "\n### Similar Documents (by embedding) ###"
    knn_response = ELASTICSEARCH_CLIENT.search(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: {
        knn: {
          field: 'body_embedding',
          query_vector: embedding,
          k: 11,  # +1 because it will include itself
          num_candidates: 100,
          filter: { term: { 'doc_project_join' => 'doc' } }
        },
        _source: ['sourcedb', 'sourceid', 'body']
      }
    )

    hits = knn_response.dig('hits', 'hits') || []
    hits.reject! { |h| h['_id'].to_i == doc_id }  # Remove self

    puts "Found #{hits.size} similar documents:\n"
    hits.first(10).each_with_index do |hit, idx|
      source = hit['_source']
      puts "  #{idx + 1}. [#{hit['_score'].round(3)}] #{source['sourcedb']}:#{source['sourceid']}"
      puts "     #{truncate_text(source['body'], 100)}"
      puts ""
    end
  end

  private

  def bm25_search(query, size)
    response = ELASTICSEARCH_CLIENT.search(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: {
        query: {
          bool: {
            must: { match: { body: { query: query } } },
            filter: { term: { 'doc_project_join' => 'doc' } }
          }
        },
        _source: ['sourcedb', 'sourceid', 'body'],
        size: size
      }
    )

    {
      total: response.dig('hits', 'total', 'value') || 0,
      hits: (response.dig('hits', 'hits') || []).map do |hit|
        {
          id: hit['_id'].to_i,
          score: hit['_score'],
          sourcedb: hit.dig('_source', 'sourcedb'),
          sourceid: hit.dig('_source', 'sourceid'),
          body: hit.dig('_source', 'body')
        }
      end
    }
  end

  def knn_search(query, size)
    # Generate embedding for query
    embedding = EmbeddingService.generate(query)
    return { error: 'Failed to generate query embedding' } unless embedding

    response = ELASTICSEARCH_CLIENT.search(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: {
        knn: {
          field: 'body_embedding',
          query_vector: embedding,
          k: size,
          num_candidates: size * 10,
          filter: { term: { 'doc_project_join' => 'doc' } }
        },
        _source: ['sourcedb', 'sourceid', 'body']
      }
    )

    {
      total: response.dig('hits', 'total', 'value') || 0,
      hits: (response.dig('hits', 'hits') || []).map do |hit|
        {
          id: hit['_id'].to_i,
          score: hit['_score'],
          sourcedb: hit.dig('_source', 'sourcedb'),
          sourceid: hit.dig('_source', 'sourceid'),
          body: hit.dig('_source', 'body')
        }
      end
    }
  end

  def truncate_text(text, max_length)
    return '' if text.nil?
    return text if text.length <= max_length

    text[0...max_length].gsub(/\s+\S*$/, '') + '...'
  end
end
