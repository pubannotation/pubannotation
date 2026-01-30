# frozen_string_literal: true

# SearchResults wraps Elasticsearch response with ActiveRecord integration and pagination
#
# This class provides a compatible interface for views that expect:
# - .records - ActiveRecord collection for the matched documents
# - .results - Raw ES results with scores and highlights
# - .total - Total count of matching documents
# - Pagination via Kaminari-compatible methods
#
# Usage:
#   results = Doc.search_by_elasticsearch('cancer', project, nil, 1, 10)
#   results.records  # => ActiveRecord::Relation of Doc objects
#   results.total    # => Integer total count
#   results[0].highlight.body  # => Array of highlighted snippets
#
class SearchResults
  include Enumerable

  attr_reader :response, :model_class, :page, :per

  def initialize(response, model_class, page: 1, per: 10)
    @response = response
    @model_class = model_class
    @page = page
    @per = per
    @records_cache = nil
    @results_cache = nil
  end

  # Total number of matching documents
  # @return [Integer]
  def total
    hits_total = response.dig('hits', 'total')
    case hits_total
    when Hash
      hits_total['value']
    when Integer
      hits_total
    else
      0
    end
  end

  alias_method :total_count, :total

  # Raw ES hits with metadata (scores, highlights)
  # @return [Array<SearchResult>]
  def results
    @results_cache ||= hits.map { |hit| SearchResult.new(hit) }
  end

  # ActiveRecord relation for matched documents, preserving ES ordering
  # @return [ActiveRecord::Relation]
  def records
    @records_cache ||= load_records
  end

  # Enumerable: iterate over search results
  def each(&block)
    results.each(&block)
  end

  # Array-like access to results
  def [](index)
    results[index]
  end

  # Number of results in current page
  def size
    results.size
  end

  alias_method :length, :size

  # Check if results are empty
  def empty?
    results.empty?
  end

  # Pagination support (Kaminari-compatible)

  def current_page
    page
  end

  def limit_value
    per
  end

  alias_method :per_page, :limit_value

  def total_pages
    (total.to_f / per).ceil
  end

  alias_method :num_pages, :total_pages

  def first_page?
    page == 1
  end

  def last_page?
    page >= total_pages
  end

  def out_of_range?
    page > total_pages
  end

  # Offset for current page (0-indexed)
  def offset
    (page - 1) * per
  end

  # ES aggregations (if any)
  def aggregations
    response['aggregations'] || {}
  end

  # Max score from ES response
  def max_score
    response.dig('hits', 'max_score')
  end

  # Time taken for ES query (ms)
  def took
    response['took']
  end

  # Was the query timed out?
  def timed_out?
    response['timed_out']
  end

  # Return self for compatibility with pagination helpers
  def page(num)
    self
  end

  def per(num)
    self
  end

  private

  def hits
    response.dig('hits', 'hits') || []
  end

  def doc_ids
    hits.map { |hit| hit['_id'].to_i }
  end

  def load_records
    return model_class.none if doc_ids.empty?

    # Load records and preserve ES ordering
    records_by_id = model_class.where(id: doc_ids).index_by(&:id)
    doc_ids.map { |id| records_by_id[id] }.compact
  end

  # Inner class representing a single search result with ES metadata
  class SearchResult
    attr_reader :hit

    def initialize(hit)
      @hit = hit
    end

    def id
      hit['_id']
    end

    def score
      hit['_score']
    end

    # RRF score (combined score from hybrid search)
    def rrf_score
      hit['_rrf_score']
    end

    # BM25 text search score (nil if not in BM25 results)
    def bm25_score
      hit['_bm25_score']
    end

    # kNN vector similarity score (nil if not in kNN results)
    def knn_score
      hit['_knn_score']
    end

    # BM25 rank (1-based, nil if not in BM25 results)
    def bm25_rank
      hit['_bm25_rank']
    end

    # kNN rank (1-based, nil if not in kNN results)
    def knn_rank
      hit['_knn_rank']
    end

    # Check if this is a hybrid search result (has RRF score)
    def hybrid?
      hit['_rrf_score'].present?
    end

    def source
      hit['_source'] || {}
    end

    def highlight
      @highlight ||= Highlight.new(hit['highlight'] || {})
    end

    def sourcedb
      source['sourcedb']
    end

    def sourceid
      source['sourceid']
    end

    def body
      source['body']
    end

    # Delegate method_missing to source for easy field access
    def method_missing(method, *args)
      key = method.to_s
      if source.key?(key)
        source[key]
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      source.key?(method.to_s) || super
    end
  end

  # Inner class for highlight access
  class Highlight
    attr_reader :data

    def initialize(data)
      @data = data
    end

    def body
      data['body'] || []
    end

    def [](field)
      data[field.to_s] || []
    end

    def method_missing(method, *args)
      key = method.to_s
      data[key] || []
    end

    def respond_to_missing?(method, include_private = false)
      true  # Always respond to field access
    end
  end
end
