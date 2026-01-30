# frozen_string_literal: true

# ElasticsearchBulkIndexJob processes queued Elasticsearch operations in batches
#
# This job is designed to be triggered automatically when the queue reaches
# a certain size, or can be manually triggered via rake task.
#
# Features:
# - Processes operations in batches of 500 for efficiency
# - Disables ES refresh during bulk operations for better performance
# - Automatically re-queues itself if more work remains
# - Reports progress for large batches
#
# Usage:
#   ElasticsearchBulkIndexJob.perform_later
#   ElasticsearchBulkIndexJob.perform_now  # Synchronous
#
class ElasticsearchBulkIndexJob < ApplicationJob
  queue_as :elasticsearch

  BATCH_SIZE = 500
  MAX_BATCHES_PER_RUN = 20  # Process up to 10,000 ops per job run

  def perform(options = {})
    @queue = Elasticsearch::IndexQueue.instance
    @manager = Elasticsearch::IndexManager.new
    @options = options.symbolize_keys
    @batches_processed = 0
    @total_processed = 0
    @errors = []

    log_start
    process_queue
    log_completion
  rescue => e
    Rails.logger.error "[ES BulkIndex] Job failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise
  end

  def job_name
    'Elasticsearch Bulk Index'
  end

  private

  def process_queue
    # Process batches until queue is empty or we hit the limit
    while @batches_processed < MAX_BATCHES_PER_RUN
      batch = @queue.pop_batch(batch_size: BATCH_SIZE)
      break if batch.empty?

      results = @queue.process_batch(batch)
      @total_processed += results[:processed]
      @errors.concat(results[:errors]) if results[:errors].any?
      @batches_processed += 1

      log_progress if @batches_processed % 5 == 0
    end

    # If there's more work, schedule another job
    schedule_continuation if @queue.queue_size > 0
  end

  def schedule_continuation
    Rails.logger.info "[ES BulkIndex] Queue still has #{@queue.queue_size} items, scheduling continuation"
    ElasticsearchBulkIndexJob.perform_later
  end

  def log_start
    Rails.logger.info "[ES BulkIndex] Starting job, queue size: #{@queue.queue_size}"
  end

  def log_progress
    Rails.logger.info "[ES BulkIndex] Progress: #{@total_processed} operations processed, " \
                      "#{@batches_processed} batches, #{@errors.size} errors"
  end

  def log_completion
    Rails.logger.info "[ES BulkIndex] Completed: #{@total_processed} operations in #{@batches_processed} batches"
    if @errors.any?
      Rails.logger.warn "[ES BulkIndex] Errors encountered: #{@errors.size}"
      @errors.first(10).each do |error|
        Rails.logger.warn "[ES BulkIndex] Error: #{error.inspect}"
      end
    end
  end
end
