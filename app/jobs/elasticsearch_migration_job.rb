# frozen_string_literal: true

# ElasticsearchMigrationJob handles zero-downtime reindexing from PostgreSQL
#
# This job creates a new index, reindexes all documents from the database,
# and atomically switches the alias when complete.
#
# Usage:
#   ElasticsearchMigrationJob.perform_later(version: 2)
#   ElasticsearchMigrationJob.perform_later(version: 2, include_memberships: true)
#
class ElasticsearchMigrationJob < ApplicationJob
  queue_as :elasticsearch

  BATCH_SIZE = 500

  def perform(options = {})
    @options = options.symbolize_keys
    @version = @options[:version] || next_version
    @include_memberships = @options.fetch(:include_memberships, true)
    @manager = Elasticsearch::IndexManager.new
    @processed = 0
    @errors = []

    log_start
    run_migration
    log_completion
  end

  def job_name
    'Elasticsearch Migration'
  end

  private

  def run_migration
    # Step 1: Create new index
    create_new_index

    # Step 2: Disable refresh for faster bulk indexing
    @manager.disable_refresh(version: @version)

    # Step 3-4: Index documents and memberships (with logging silenced)
    silence_logging do
      index_all_documents
      index_all_memberships if @include_memberships
    end

    # Step 5: Re-enable refresh
    @manager.enable_refresh(version: @version)

    # Step 6: Refresh the index to make all docs searchable
    @manager.refresh(version: @version)

    # Step 7: Switch alias to new index
    switch_alias_if_requested
  rescue => e
    Rails.logger.error "[ES Migration] Migration failed: #{e.message}"
    raise
  end

  def create_new_index
    puts "[ES Migration] Creating index version #{@version}..."
    @manager.create_index(version: @version)
  end

  def index_all_documents
    @total_docs = Doc.count
    puts "[ES Migration] Indexing #{@total_docs} documents..."

    prepare_progress_record(@total_docs) if @job

    index_name = Elasticsearch::Config.index_name(@version)
    @last_percent = 0

    Doc.find_in_batches(batch_size: BATCH_SIZE) do |docs|
      bulk_body = []

      docs.each do |doc|
        bulk_body << {
          index: {
            _index: index_name,
            _id: doc.id.to_s,
            routing: doc.id.to_s
          }
        }
        bulk_body << {
          doc_project_join: { name: 'doc' },
          sourcedb: doc.sourcedb,
          sourceid: doc.sourceid,
          body: doc.body,
          created_at: doc.created_at&.iso8601,
          updated_at: doc.updated_at&.iso8601
        }
      end

      execute_bulk(bulk_body)
      @processed += docs.size
      update_progress
      print_progress
    end

    puts ""
    puts "[ES Migration] Indexed #{@processed} documents"
  end

  def index_all_memberships
    total_memberships = ProjectDoc.count
    puts "[ES Migration] Indexing #{total_memberships} project memberships..."

    index_name = Elasticsearch::Config.index_name(@version)
    membership_count = 0
    last_percent = 0

    # Load all projects into memory for name lookup (efficient for reasonable project counts)
    projects_by_id = Project.all.index_by(&:id)

    ProjectDoc.find_in_batches(batch_size: BATCH_SIZE) do |project_docs|
      bulk_body = []

      project_docs.each do |pd|
        membership_id = "#{pd.doc_id}_#{pd.project_id}"
        project = projects_by_id[pd.project_id]

        bulk_body << {
          index: {
            _index: index_name,
            _id: membership_id,
            routing: pd.doc_id.to_s
          }
        }
        bulk_body << {
          doc_project_join: { name: 'project_membership', parent: pd.doc_id.to_s },
          project_id: pd.project_id,
          project_name: project&.name
        }
      end

      execute_bulk(bulk_body)
      membership_count += project_docs.size

      # Print progress
      percent = (membership_count * 100.0 / total_memberships).to_i
      if percent > last_percent
        last_percent = percent
        print "\r[ES Migration] Memberships: #{percent}% (#{membership_count}/#{total_memberships})    "
        $stdout.flush
      end
    end

    puts ""
    puts "[ES Migration] Indexed #{membership_count} project memberships"
  end

  def execute_bulk(bulk_body)
    return if bulk_body.empty?

    response = ELASTICSEARCH_CLIENT.bulk(body: bulk_body, refresh: false)

    if response['errors']
      error_items = response['items'].select { |item| item.values.first['error'] }
      error_items.each do |item|
        error = item.values.first['error']
        @errors << "#{error['type']}: #{error['reason']}"
      end
    end
  rescue => e
    @errors << e.message
  end

  def switch_alias_if_requested
    return unless @options.fetch(:switch_alias, true)

    puts "[ES Migration] Switching alias to version #{@version}..."
    @manager.switch_alias(to_version: @version)
  end

  def next_version
    current = @manager.current_version
    current ? current + 1 : 1
  end

  def update_progress
    return unless @job

    @job.update(
      num_dones: @processed,
      messages: @errors.any? ? @errors.last(10) : nil
    )
  end

  def print_progress
    return unless @total_docs

    percent = (@processed * 100.0 / @total_docs).to_i
    return if percent == @last_percent

    @last_percent = percent
    print "\r[ES Migration] Documents: #{percent}% (#{@processed}/#{@total_docs})    "
    $stdout.flush
  end

  def log_start
    puts "[ES Migration] Starting migration to version #{@version}"
  end

  def log_completion
    stats = @manager.index_stats(version: @version)
    puts "[ES Migration] Complete: #{stats[:docs_count]} docs, #{stats[:store_size_human]}"
    puts "[ES Migration] Errors: #{@errors.size}" if @errors.any?
  end

  def silence_logging
    old_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil
    yield
  ensure
    ActiveRecord::Base.logger = old_logger
  end
end
