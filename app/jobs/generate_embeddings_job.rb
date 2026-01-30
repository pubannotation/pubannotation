# frozen_string_literal: true

# GenerateEmbeddingsJob generates PubMedBERT embeddings for documents
#
# This job processes documents in batches, generating embeddings for their
# body text and updating Elasticsearch with the vectors for semantic search.
#
# Text is truncated client-side to ~3000 chars (~500 tokens) before sending
# to the embedding server, so batch size is based on document count.
#
# Usage:
#   GenerateEmbeddingsJob.perform_later                    # All docs without embeddings
#   GenerateEmbeddingsJob.perform_later(doc_ids: [1,2,3])  # Specific docs
#   GenerateEmbeddingsJob.perform_later(project_id: 123)   # All docs in a project
#
class GenerateEmbeddingsJob < ApplicationJob
  queue_as :elasticsearch

  BATCH_SIZE = 50  # Docs per batch (truncated to ~3KB each)

  def perform(options = {})
    @options = options.symbolize_keys
    @processed = 0
    @failed = 0
    @skipped = 0

    log_start
    process_documents
    log_completion
  end

  def job_name
    'Generate Embeddings'
  end

  private

  def process_documents
    doc_ids = determine_doc_ids
    return if doc_ids.empty?

    @total_docs = doc_ids.size
    total_batches = (@total_docs.to_f / BATCH_SIZE).ceil
    @last_percent = 0

    # Silence ActiveRecord logging during batch processing
    silence_logging do
      doc_ids.each_slice(BATCH_SIZE).with_index do |batch_ids, batch_num|
        process_batch(batch_ids)
        update_progress if @job
        print_progress(batch_num + 1, total_batches)
      end
    end
    puts ""  # Newline after progress
  end

  def determine_doc_ids
    offset = @options[:offset] || 0
    limit = @options[:limit]

    if @options[:doc_ids].present?
      @options[:doc_ids]
    elsif @options[:project_id].present?
      project = Project.find_by(id: @options[:project_id])
      return [] unless project

      query = project.docs.order(:id).offset(offset)
      query = query.limit(limit) if limit
      query.pluck(:id)
    else
      query = Doc.order(:id).offset(offset)
      query = query.limit(limit) if limit
      query.pluck(:id)
    end
  end

  def process_batch(doc_ids)
    docs = Doc.where(id: doc_ids).select(:id, :body).to_a

    # Extract texts for batch embedding
    texts = docs.map { |doc| doc.body.to_s }

    # Generate embeddings in single batch request
    embeddings = EmbeddingService.generate_batch(texts)

    # Build bulk update body
    bulk_body = []
    docs.each_with_index do |doc, idx|
      embedding = embeddings[idx]

      if embedding.nil?
        @failed += 1
        next
      end

      bulk_body << { update: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: doc.id.to_s, routing: doc.id.to_s } }
      bulk_body << { doc: { body_embedding: embedding }, doc_as_upsert: false }
      @processed += 1
    end

    # Execute bulk update to ES
    if bulk_body.any?
      begin
        response = ELASTICSEARCH_CLIENT.bulk(body: bulk_body, refresh: false)
        if response['errors']
          error_count = response['items'].count { |item| item.values.first['error'] }
          @failed += error_count
          @processed -= error_count
        end
      rescue => e
        Rails.logger.error "[GenerateEmbeddings] Bulk failed: #{e.message}"
        @failed += bulk_body.size / 2
        @processed -= bulk_body.size / 2
      end
    end
  rescue => e
    Rails.logger.error "[GenerateEmbeddings] Batch failed: #{e.class} - #{e.message}"
    @failed += doc_ids.size
  end

  def print_progress(batch_num, total_batches)
    percent = (batch_num * 100.0 / total_batches).to_i
    return if percent == @last_percent && percent < 100

    @last_percent = percent
    print "\r[GenerateEmbeddings] #{percent}% (#{@processed}/#{@total_docs} docs, #{@failed} failed)    "
    $stdout.flush
  end

  def update_progress
    return unless @job

    @job.update(
      num_dones: @processed,
      messages: ["Processed: #{@processed}, Failed: #{@failed}, Skipped: #{@skipped}"]
    )
  end

  def log_start
    puts "[GenerateEmbeddings] Starting..."
  end

  def log_completion
    puts "[GenerateEmbeddings] Done: #{@processed} processed, #{@failed} failed"
  end

  def silence_logging
    old_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil
    yield
  ensure
    ActiveRecord::Base.logger = old_logger
  end
end
