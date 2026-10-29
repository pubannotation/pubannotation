# frozen_string_literal: true

# Doc::ElasticsearchIndexable concern provides queue-based Elasticsearch indexing
# for Doc. It replaces the synchronous elasticsearch-model callbacks with
# asynchronous Redis-based queue operations.
#
# Usage:
#   class Doc < ApplicationRecord
#     include Doc::ElasticsearchIndexable
#   end
#
# This will automatically:
#   - Queue document for indexing on create/update
#   - Queue document for deletion on destroy
#
module Doc::ElasticsearchIndexable
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
