# frozen_string_literal: true

# EmbeddingService provides text embeddings using PubMedBERT via Ollama API
#
# PubMedBERT is specifically trained on biomedical literature (PubMed abstracts
# and PMC full-text), providing superior semantic understanding for biomedical
# terms compared to general-purpose embedding models.
#
# Configuration:
#   PUBMEDBERT_EMBED_URL - URL to the embedding server (default: http://172.18.8.61:11435/api/embed)
#
# Usage:
#   embedding = EmbeddingService.generate("p53 tumor suppressor protein")
#   # => [0.123, -0.456, ...] (768-dimensional vector)
#
#   embeddings = EmbeddingService.generate_batch(["text1", "text2"])
#   # => [[0.123, ...], [0.456, ...]]
#
class EmbeddingService
  BASE_URL = ENV.fetch('PUBMEDBERT_EMBED_URL', 'http://localhost:11435')
  SINGLE_ENDPOINT = '/api/embeddings'  # Single text embedding
  BATCH_ENDPOINT = '/api/embed'        # Batch text embeddings
  EMBEDDING_DIMS = 768  # PubMedBERT dimension
  DEFAULT_TIMEOUT = 120  # seconds (increased for large batches)
  MAX_TEXT_LENGTH = 3000  # ~500 tokens at ~6 chars/token for biomedical text
  MODEL_NAME = 'pubmedbert'

  class EmbeddingError < StandardError; end

  class << self
    # Generate embedding for a single text
    # @param text [String] Text to embed
    # @param truncate [Boolean] Truncate text if too long (default: true)
    # @return [Array<Float>, nil] 768-dimensional embedding vector or nil on failure
    def generate(text, truncate: true)
      return nil if text.blank?

      text = truncate_text(text) if truncate

      response = make_single_request(text)
      return nil unless response

      response['embedding']
    rescue => e
      Rails.logger.error "[EmbeddingService] Error generating embedding: #{e.message}"
      nil
    end

    # Generate embeddings for multiple texts in batch
    # @param texts [Array<String>] Array of texts to embed
    # @param truncate [Boolean] Truncate texts if too long
    # @return [Array<Array<Float>>] Array of embedding vectors (nil for failed items)
    def generate_batch(texts, truncate: true)
      return [] if texts.blank?

      texts = texts.map { |t| truncate ? truncate_text(t) : t }

      response = make_batch_request(texts)
      return Array.new(texts.size, nil) unless response

      response['embeddings'] || Array.new(texts.size, nil)
    rescue => e
      Rails.logger.error "[EmbeddingService] Error generating batch embeddings: #{e.message}"
      Array.new(texts.size, nil)
    end

    # Check if the embedding service is available
    # @return [Boolean]
    def available?
      response = make_single_request('test', timeout: 5)
      response.present?
    rescue
      false
    end

    # Get the expected embedding dimensions
    # @return [Integer]
    def dimensions
      EMBEDDING_DIMS
    end

    # Compute cosine similarity between two embeddings
    # @param embedding1 [Array<Float>]
    # @param embedding2 [Array<Float>]
    # @return [Float] Similarity score between -1 and 1
    def cosine_similarity(embedding1, embedding2)
      return nil unless embedding1 && embedding2
      return nil if embedding1.size != embedding2.size

      dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
      magnitude1 = Math.sqrt(embedding1.sum { |x| x * x })
      magnitude2 = Math.sqrt(embedding2.sum { |x| x * x })

      return 0.0 if magnitude1.zero? || magnitude2.zero?

      dot_product / (magnitude1 * magnitude2)
    end

    private

    # Single text embedding: POST /api/embeddings with {"prompt": "text", "model": "..."}
    def make_single_request(text, timeout: DEFAULT_TIMEOUT)
      require 'httpx'

      url = "#{BASE_URL}#{SINGLE_ENDPOINT}"
      response = HTTPX.with(timeout: { operation_timeout: timeout })
                      .post(url, json: {
                        prompt: text,
                        model: MODEL_NAME
                      })

      unless response.status == 200
        Rails.logger.warn "[EmbeddingService] Single request failed with status #{response.status}"
        return nil
      end

      JSON.parse(response.body.to_s)
    rescue HTTPX::TimeoutError
      Rails.logger.warn "[EmbeddingService] Request timed out"
      nil
    rescue JSON::ParserError => e
      Rails.logger.warn "[EmbeddingService] Invalid JSON response: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "[EmbeddingService] Request error: #{e.class} - #{e.message}"
      nil
    end

    # Batch text embeddings: POST /api/embed with {"input": [...], "model": "..."}
    def make_batch_request(texts, timeout: DEFAULT_TIMEOUT)
      require 'httpx'

      url = "#{BASE_URL}#{BATCH_ENDPOINT}"
      response = HTTPX.with(timeout: { operation_timeout: timeout })
                      .post(url, json: {
                        input: texts,
                        model: MODEL_NAME
                      })

      unless response.status == 200
        Rails.logger.warn "[EmbeddingService] Batch request failed with status #{response.status}"
        return nil
      end

      JSON.parse(response.body.to_s)
    rescue HTTPX::TimeoutError
      Rails.logger.warn "[EmbeddingService] Request timed out"
      nil
    rescue JSON::ParserError => e
      Rails.logger.warn "[EmbeddingService] Invalid JSON response: #{e.message}"
      nil
    rescue => e
      Rails.logger.error "[EmbeddingService] Request error: #{e.class} - #{e.message}"
      nil
    end

    def truncate_text(text)
      return text if text.nil? || text.length <= MAX_TEXT_LENGTH

      # Truncate to max length, trying to break at word boundary
      truncated = text[0...MAX_TEXT_LENGTH]
      last_space = truncated.rindex(' ')

      if last_space && last_space > MAX_TEXT_LENGTH * 0.8
        truncated[0...last_space]
      else
        truncated
      end
    end
  end
end
