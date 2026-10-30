# frozen_string_literal: true

class DocumentElasticsearchIndexer
  def self.index!(doc)
    bulk_body = [
      { index: { _index: ELASTICSEARCH_INDEX_ALIAS, _id: doc.id.to_s, routing: doc.id.to_s } },
      {
        doc_project_join: { name: 'doc' },
        sourcedb: doc.sourcedb,
        sourceid: doc.sourceid,
        body: doc.body,
        created_at: doc.created_at&.iso8601,
        updated_at: doc.updated_at&.iso8601
      }
    ]
    ELASTICSEARCH_CLIENT.bulk(body: bulk_body, refresh: true)
  end
end
