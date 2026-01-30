# frozen_string_literal: true

# ElasticsearchSyncJob verifies and repairs sync between PostgreSQL and Elasticsearch
#
# This job compares document counts and IDs between the database and ES index,
# identifying and optionally repairing discrepancies.
#
# Usage:
#   ElasticsearchSyncJob.perform_later                        # Verify only
#   ElasticsearchSyncJob.perform_later(repair: true)          # Verify and repair
#   ElasticsearchSyncJob.perform_later(project_id: 123)       # Verify specific project
#
class ElasticsearchSyncJob < ApplicationJob
  queue_as :elasticsearch

  BATCH_SIZE = 1000

  def perform(options = {})
    @options = options.symbolize_keys
    @repair = @options.fetch(:repair, false)
    @project_id = @options[:project_id]
    @discrepancies = {
      missing_in_es: [],
      missing_in_db: [],
      membership_issues: []
    }
    @stats = { docs_in_db: 0, docs_in_es: 0, memberships_in_db: 0 }

    log_start
    run_verification
    run_repairs if @repair && has_discrepancies?
    log_completion
  end

  def job_name
    'Elasticsearch Sync Verification'
  end

  private

  def run_verification
    verify_document_counts
    verify_document_ids
    verify_memberships if @project_id.present?
  end

  def verify_document_counts
    # Count in PostgreSQL
    @stats[:docs_in_db] = Doc.count

    # Count in Elasticsearch (only parent docs, not memberships)
    begin
      response = ELASTICSEARCH_CLIENT.count(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: {
          query: { term: { 'doc_project_join' => 'doc' } }
        }
      )
      @stats[:docs_in_es] = response['count']
    rescue => e
      Rails.logger.error "[ES Sync] Failed to count ES docs: #{e.message}"
      @stats[:docs_in_es] = -1
    end

    Rails.logger.info "[ES Sync] Document counts - DB: #{@stats[:docs_in_db]}, ES: #{@stats[:docs_in_es]}"
  end

  def verify_document_ids
    # Get all doc IDs from PostgreSQL
    db_doc_ids = Set.new(Doc.pluck(:id))

    # Get all doc IDs from Elasticsearch
    es_doc_ids = Set.new
    scroll_es_doc_ids do |ids|
      es_doc_ids.merge(ids)
    end

    # Find discrepancies
    @discrepancies[:missing_in_es] = (db_doc_ids - es_doc_ids).to_a
    @discrepancies[:missing_in_db] = (es_doc_ids - db_doc_ids).to_a

    Rails.logger.info "[ES Sync] Missing in ES: #{@discrepancies[:missing_in_es].size}"
    Rails.logger.info "[ES Sync] Missing in DB (orphan in ES): #{@discrepancies[:missing_in_db].size}"
  end

  def verify_memberships
    project = Project.find_by(id: @project_id)
    return unless project

    # Get membership counts
    db_membership_doc_ids = Set.new(project.project_docs.pluck(:doc_id))
    @stats[:memberships_in_db] = db_membership_doc_ids.size

    # Get memberships from ES for this project
    es_membership_doc_ids = Set.new
    scroll_es_memberships(@project_id) do |doc_ids|
      es_membership_doc_ids.merge(doc_ids)
    end

    # Find discrepancies
    missing_memberships = (db_membership_doc_ids - es_membership_doc_ids).to_a
    extra_memberships = (es_membership_doc_ids - db_membership_doc_ids).to_a

    @discrepancies[:membership_issues] = {
      missing: missing_memberships,
      extra: extra_memberships,
      project_id: @project_id
    }

    Rails.logger.info "[ES Sync] Project #{@project_id} memberships - DB: #{db_membership_doc_ids.size}, ES: #{es_membership_doc_ids.size}"
    Rails.logger.info "[ES Sync] Missing memberships: #{missing_memberships.size}, Extra: #{extra_memberships.size}"
  end

  def run_repairs
    Rails.logger.info "[ES Sync] Starting repairs..."

    # Repair missing documents in ES
    if @discrepancies[:missing_in_es].any?
      Rails.logger.info "[ES Sync] Queueing #{@discrepancies[:missing_in_es].size} docs for indexing"
      @discrepancies[:missing_in_es].each_slice(500) do |batch|
        Elasticsearch::IndexQueue.index_docs(batch)
      end
    end

    # Delete orphan documents from ES
    if @discrepancies[:missing_in_db].any?
      Rails.logger.info "[ES Sync] Deleting #{@discrepancies[:missing_in_db].size} orphan docs from ES"
      delete_orphan_docs(@discrepancies[:missing_in_db])
    end

    # Repair membership issues
    if @discrepancies[:membership_issues].is_a?(Hash)
      missing = @discrepancies[:membership_issues][:missing] || []
      extra = @discrepancies[:membership_issues][:extra] || []
      project_id = @discrepancies[:membership_issues][:project_id]

      if missing.any?
        Rails.logger.info "[ES Sync] Adding #{missing.size} missing project memberships"
        Elasticsearch::IndexQueue.add_project_memberships(doc_ids: missing, project_id: project_id)
      end

      if extra.any?
        Rails.logger.info "[ES Sync] Removing #{extra.size} extra project memberships"
        Elasticsearch::IndexQueue.remove_project_memberships(doc_ids: extra, project_id: project_id)
      end
    end

    # Trigger processing
    Elasticsearch::IndexQueue.schedule_processing

    Rails.logger.info "[ES Sync] Repairs queued"
  end

  def scroll_es_doc_ids
    response = ELASTICSEARCH_CLIENT.search(
      index: ELASTICSEARCH_INDEX_ALIAS,
      scroll: '5m',
      size: BATCH_SIZE,
      body: {
        query: { term: { 'doc_project_join' => 'doc' } },
        _source: false
      }
    )

    while response['hits']['hits'].any?
      ids = response['hits']['hits'].map { |hit| hit['_id'].to_i }
      yield ids

      response = ELASTICSEARCH_CLIENT.scroll(
        scroll_id: response['_scroll_id'],
        scroll: '5m'
      )
    end

    # Clear scroll
    ELASTICSEARCH_CLIENT.clear_scroll(scroll_id: response['_scroll_id']) rescue nil
  end

  def scroll_es_memberships(project_id)
    response = ELASTICSEARCH_CLIENT.search(
      index: ELASTICSEARCH_INDEX_ALIAS,
      scroll: '5m',
      size: BATCH_SIZE,
      body: {
        query: {
          bool: {
            must: [
              { term: { 'doc_project_join' => 'project_membership' } },
              { term: { project_id: project_id } }
            ]
          }
        },
        _source: ['project_id']
      }
    )

    while response['hits']['hits'].any?
      # Extract doc_id from the routing (which is the parent doc_id)
      doc_ids = response['hits']['hits'].map do |hit|
        hit['_routing']&.to_i || hit['_id'].split('_').first.to_i
      end
      yield doc_ids

      response = ELASTICSEARCH_CLIENT.scroll(
        scroll_id: response['_scroll_id'],
        scroll: '5m'
      )
    end

    ELASTICSEARCH_CLIENT.clear_scroll(scroll_id: response['_scroll_id']) rescue nil
  end

  def delete_orphan_docs(doc_ids)
    doc_ids.each_slice(500) do |batch|
      bulk_body = batch.flat_map do |doc_id|
        [{ delete: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: doc_id.to_s, routing: doc_id.to_s } }]
      end

      ELASTICSEARCH_CLIENT.bulk(body: bulk_body, refresh: false)
    end
  end

  def has_discrepancies?
    @discrepancies[:missing_in_es].any? ||
      @discrepancies[:missing_in_db].any? ||
      (@discrepancies[:membership_issues].is_a?(Hash) &&
        (@discrepancies[:membership_issues][:missing]&.any? ||
         @discrepancies[:membership_issues][:extra]&.any?))
  end

  def log_start
    Rails.logger.info "[ES Sync] Starting verification (repair: #{@repair})"
  end

  def log_completion
    Rails.logger.info "[ES Sync] Verification complete"
    Rails.logger.info "[ES Sync] Stats: #{@stats.inspect}"
    Rails.logger.info "[ES Sync] Discrepancies: #{discrepancy_summary}"
  end

  def discrepancy_summary
    {
      missing_in_es: @discrepancies[:missing_in_es].size,
      missing_in_db: @discrepancies[:missing_in_db].size,
      membership_issues: @discrepancies[:membership_issues].is_a?(Hash) ? {
        missing: @discrepancies[:membership_issues][:missing]&.size || 0,
        extra: @discrepancies[:membership_issues][:extra]&.size || 0
      } : 0
    }
  end
end
