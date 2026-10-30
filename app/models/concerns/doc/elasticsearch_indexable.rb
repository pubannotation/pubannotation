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

  # Queue ES project membership operations (called by association callbacks)
  def queue_es_project_add(project)
    Elasticsearch::IndexQueue.add_project_membership(doc_id: id, project_id: project.id)
  end

  def queue_es_project_remove(project)
    Elasticsearch::IndexQueue.remove_project_membership(doc_id: id, project_id: project.id)
  end

  # Queue this document for indexing
  def queue_es_index
    Elasticsearch::IndexQueue.index_doc(id)
  end

  # Queue this document for deletion
  def queue_es_delete
    Elasticsearch::IndexQueue.delete_doc(id)
  end

end
