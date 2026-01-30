# frozen_string_literal: true

module Elasticsearch
  # IndexQueue manages a Redis-based queue for Elasticsearch indexing operations
  # Operations are batched and processed asynchronously by ElasticsearchBulkIndexJob
  #
  # Operation Types:
  #   - :index_doc - Index a document (parent)
  #   - :delete_doc - Delete a document and all its project memberships
  #   - :add_project_membership - Add project membership (child)
  #   - :remove_project_membership - Remove project membership (child)
  #
  # Usage:
  #   queue = Elasticsearch::IndexQueue.new
  #   queue.enqueue_doc(doc_id: 1, operation: :index_doc)
  #   queue.enqueue_project_membership(doc_id: 1, project_id: 5, operation: :add_project_membership)
  #   queue.flush # Process immediately
  #
  class IndexQueue
    QUEUE_KEY = 'elasticsearch:index_queue'
    BATCH_SIZE = 500
    OPERATIONS = %i[index_doc delete_doc add_project_membership remove_project_membership update_embedding].freeze

    class << self
      def instance
        @instance ||= new
      end

      # Convenience methods for common operations
      def index_doc(doc_id)
        instance.enqueue_doc(doc_id: doc_id, operation: :index_doc)
      end

      def delete_doc(doc_id)
        instance.enqueue_doc(doc_id: doc_id, operation: :delete_doc)
      end

      def add_project_membership(doc_id:, project_id:)
        instance.enqueue_project_membership(doc_id: doc_id, project_id: project_id, operation: :add_project_membership)
      end

      def remove_project_membership(doc_id:, project_id:)
        instance.enqueue_project_membership(doc_id: doc_id, project_id: project_id, operation: :remove_project_membership)
      end

      def update_embedding(doc_id)
        instance.enqueue_doc(doc_id: doc_id, operation: :update_embedding)
      end

      # Enqueue multiple docs at once
      def index_docs(doc_ids)
        instance.enqueue_docs(doc_ids: doc_ids, operation: :index_doc)
      end

      # Enqueue multiple project memberships at once
      def add_project_memberships(doc_ids:, project_id:)
        instance.enqueue_project_memberships(doc_ids: doc_ids, project_id: project_id, operation: :add_project_membership)
      end

      def remove_project_memberships(doc_ids:, project_id:)
        instance.enqueue_project_memberships(doc_ids: doc_ids, project_id: project_id, operation: :remove_project_membership)
      end

      # Trigger async processing
      def schedule_processing
        instance.schedule_processing
      end

      # Process queue synchronously (for rake tasks)
      def process_all
        instance.process_all
      end

      def queue_size
        instance.queue_size
      end

      def clear
        instance.clear
      end
    end

    def initialize(redis: nil)
      @redis = redis || Sidekiq.redis_pool
    end

    # Enqueue a document operation
    # @param doc_id [Integer] Document ID
    # @param operation [Symbol] Operation type (:index_doc, :delete_doc, :update_embedding)
    def enqueue_doc(doc_id:, operation:)
      validate_operation!(operation)

      entry = {
        type: 'doc',
        doc_id: doc_id,
        operation: operation.to_s,
        queued_at: Time.current.iso8601
      }

      push_to_queue(entry)
      schedule_processing_if_needed
    end

    # Enqueue multiple document operations
    # @param doc_ids [Array<Integer>] Document IDs
    # @param operation [Symbol] Operation type
    def enqueue_docs(doc_ids:, operation:)
      validate_operation!(operation)
      return if doc_ids.empty?

      entries = doc_ids.map do |doc_id|
        {
          type: 'doc',
          doc_id: doc_id,
          operation: operation.to_s,
          queued_at: Time.current.iso8601
        }
      end

      push_many_to_queue(entries)
      schedule_processing_if_needed
    end

    # Enqueue a project membership operation
    # @param doc_id [Integer] Document ID
    # @param project_id [Integer] Project ID
    # @param operation [Symbol] Operation type (:add_project_membership, :remove_project_membership)
    def enqueue_project_membership(doc_id:, project_id:, operation:)
      validate_operation!(operation)

      entry = {
        type: 'project_membership',
        doc_id: doc_id,
        project_id: project_id,
        operation: operation.to_s,
        queued_at: Time.current.iso8601
      }

      push_to_queue(entry)
      schedule_processing_if_needed
    end

    # Enqueue multiple project membership operations
    # @param doc_ids [Array<Integer>] Document IDs
    # @param project_id [Integer] Project ID
    # @param operation [Symbol] Operation type
    def enqueue_project_memberships(doc_ids:, project_id:, operation:)
      validate_operation!(operation)
      return if doc_ids.empty?

      entries = doc_ids.map do |doc_id|
        {
          type: 'project_membership',
          doc_id: doc_id,
          project_id: project_id,
          operation: operation.to_s,
          queued_at: Time.current.iso8601
        }
      end

      push_many_to_queue(entries)
      schedule_processing_if_needed
    end

    # Pop a batch of operations from the queue
    # @param batch_size [Integer] Maximum number of operations to fetch
    # @return [Array<Hash>] Array of operation hashes
    def pop_batch(batch_size: BATCH_SIZE)
      entries = []

      with_redis do |redis|
        batch_size.times do
          entry = redis.lpop(QUEUE_KEY)
          break unless entry

          entries << JSON.parse(entry, symbolize_names: true)
        end
      end

      entries
    end

    # Get current queue size
    # @return [Integer]
    def queue_size
      with_redis { |redis| redis.llen(QUEUE_KEY) }
    end

    # Check if queue is empty
    # @return [Boolean]
    def empty?
      queue_size == 0
    end

    # Schedule async processing if not already scheduled
    def schedule_processing
      ElasticsearchBulkIndexJob.perform_later
    end

    # Process all queued operations synchronously
    # Useful for rake tasks and testing
    def process_all
      total_processed = 0

      loop do
        batch = pop_batch
        break if batch.empty?

        process_batch(batch)
        total_processed += batch.size
      end

      total_processed
    end

    # Clear the queue (use with caution)
    def clear
      with_redis { |redis| redis.del(QUEUE_KEY) }
    end

    # Process a batch of operations
    # @param batch [Array<Hash>] Array of operation hashes
    # @return [Hash] Processing results
    def process_batch(batch)
      return { processed: 0, errors: [] } if batch.empty?

      results = { processed: 0, errors: [] }
      bulk_body = []

      # Group operations by type for efficient processing
      doc_operations = batch.select { |op| op[:type] == 'doc' }
      membership_operations = batch.select { |op| op[:type] == 'project_membership' }

      # Process document operations
      doc_operations.each do |op|
        begin
          case op[:operation].to_sym
          when :index_doc
            bulk_body.concat(build_index_doc_operations(op[:doc_id]))
          when :delete_doc
            bulk_body.concat(build_delete_doc_operations(op[:doc_id]))
          when :update_embedding
            bulk_body.concat(build_update_embedding_operations(op[:doc_id]))
          end
        rescue => e
          results[:errors] << { operation: op, error: e.message }
        end
      end

      # Process membership operations
      membership_operations.each do |op|
        begin
          case op[:operation].to_sym
          when :add_project_membership
            bulk_body.concat(build_add_membership_operations(op[:doc_id], op[:project_id]))
          when :remove_project_membership
            bulk_body.concat(build_remove_membership_operations(op[:doc_id], op[:project_id]))
          end
        rescue => e
          results[:errors] << { operation: op, error: e.message }
        end
      end

      # Execute bulk request if we have operations
      if bulk_body.any?
        begin
          response = ELASTICSEARCH_CLIENT.bulk(body: bulk_body, refresh: false)
          results[:processed] = batch.size
          results[:bulk_errors] = extract_bulk_errors(response) if response['errors']
        rescue => e
          results[:errors] << { bulk_request: true, error: e.message }
        end
      end

      results
    end

    private

    def push_to_queue(entry)
      with_redis { |redis| redis.rpush(QUEUE_KEY, entry.to_json) }
    end

    def push_many_to_queue(entries)
      return if entries.empty?

      with_redis do |redis|
        redis.pipelined do |pipeline|
          entries.each { |entry| pipeline.rpush(QUEUE_KEY, entry.to_json) }
        end
      end
    end

    def schedule_processing_if_needed
      # Schedule processing if queue has reached batch size
      schedule_processing if queue_size >= BATCH_SIZE
    end

    def validate_operation!(operation)
      unless OPERATIONS.include?(operation.to_sym)
        raise ArgumentError, "Invalid operation: #{operation}. Valid operations: #{OPERATIONS.join(', ')}"
      end
    end

    def with_redis(&block)
      if @redis.respond_to?(:with)
        @redis.with(&block)
      else
        yield @redis
      end
    end

    # Build bulk operations for indexing a document (parent doc)
    def build_index_doc_operations(doc_id)
      doc = Doc.find_by(id: doc_id)
      return [] unless doc

      [
        { index: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: doc_id.to_s, routing: doc_id.to_s } },
        {
          doc_project_join: { name: 'doc' },
          sourcedb: doc.sourcedb,
          sourceid: doc.sourceid,
          body: doc.body,
          created_at: doc.created_at&.iso8601,
          updated_at: doc.updated_at&.iso8601
        }
      ]
    end

    # Build bulk operations for deleting a document and all its memberships
    def build_delete_doc_operations(doc_id)
      # Delete the parent document (children will be orphaned but that's ok for our use case)
      [
        { delete: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: doc_id.to_s, routing: doc_id.to_s } }
      ]
    end

    # Build bulk operations for updating embedding
    def build_update_embedding_operations(doc_id)
      doc = Doc.find_by(id: doc_id)
      return [] unless doc

      embedding = EmbeddingService.generate(doc.body)
      return [] unless embedding

      [
        { update: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: doc_id.to_s, routing: doc_id.to_s } },
        { doc: { body_embedding: embedding } }
      ]
    end

    # Build bulk operations for adding a project membership (child doc)
    def build_add_membership_operations(doc_id, project_id)
      project = Project.find_by(id: project_id)
      membership_id = "#{doc_id}_#{project_id}"

      [
        { index: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: membership_id, routing: doc_id.to_s } },
        {
          doc_project_join: { name: 'project_membership', parent: doc_id.to_s },
          project_id: project_id,
          project_name: project&.name
        }
      ]
    end

    # Build bulk operations for removing a project membership
    def build_remove_membership_operations(doc_id, project_id)
      membership_id = "#{doc_id}_#{project_id}"

      [
        { delete: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: membership_id, routing: doc_id.to_s } }
      ]
    end

    def extract_bulk_errors(response)
      return [] unless response['items']

      response['items']
        .select { |item| item.values.first['error'] }
        .map { |item| item.values.first['error'] }
    end
  end
end
