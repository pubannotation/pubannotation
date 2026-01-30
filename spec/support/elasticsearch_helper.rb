# frozen_string_literal: true

# Elasticsearch Test Helper
#
# Provides utilities for integration tests that require Elasticsearch.
# Tests tagged with :elasticsearch will use a dedicated test index.
#
# Usage:
#   RSpec.describe 'Search', :elasticsearch do
#     it 'searches documents' do
#       # Test with real ES
#     end
#   end
#
# Run only ES tests:
#   bundle exec rspec --tag elasticsearch
#
# Skip ES tests:
#   bundle exec rspec --tag ~elasticsearch

module ElasticsearchTestHelper
  TEST_INDEX_VERSION = 999
  TEST_INDEX_NAME = "pubannotation_docs_v#{TEST_INDEX_VERSION}"
  TEST_INDEX_ALIAS = 'pubannotation_docs_test'

  class << self
    def elasticsearch_available?
      ELASTICSEARCH_CLIENT.ping
    rescue StandardError
      false
    end

    def rrf_available?
      return false unless elasticsearch_available?

      # Check if RRF is available (requires Platinum license)
      license = ELASTICSEARCH_CLIENT.license.get
      license_type = license.dig('license', 'type')&.downcase
      %w[platinum enterprise trial].include?(license_type)
    rescue StandardError
      false
    end

    def setup_test_index
      return unless elasticsearch_available?

      manager = Elasticsearch::IndexManager.new

      # Delete test index if it exists
      if manager.index_exists?(TEST_INDEX_NAME)
        ELASTICSEARCH_CLIENT.indices.delete(index: TEST_INDEX_NAME)
      end

      # Create test index with mapping
      mapping_path = Rails.root.join('config', 'elasticsearch', 'mappings', 'docs_v1.json')
      settings_and_mappings = JSON.parse(File.read(mapping_path))

      ELASTICSEARCH_CLIENT.indices.create(
        index: TEST_INDEX_NAME,
        body: settings_and_mappings
      )

      # Point test alias to test index
      begin
        ELASTICSEARCH_CLIENT.indices.delete_alias(index: '_all', name: TEST_INDEX_ALIAS)
      rescue Elastic::Transport::Transport::Errors::NotFound
        # Alias doesn't exist, that's fine
      end

      ELASTICSEARCH_CLIENT.indices.put_alias(index: TEST_INDEX_NAME, name: TEST_INDEX_ALIAS)
    end

    def teardown_test_index
      return unless elasticsearch_available?

      begin
        ELASTICSEARCH_CLIENT.indices.delete(index: TEST_INDEX_NAME)
      rescue Elastic::Transport::Transport::Errors::NotFound
        # Index doesn't exist, that's fine
      end
    end

    def refresh_index
      ELASTICSEARCH_CLIENT.indices.refresh(index: TEST_INDEX_NAME)
    end

    def index_document(doc, embedding: nil)
      body = {
        doc_project_join: { name: 'doc' },
        sourcedb: doc.sourcedb,
        sourceid: doc.sourceid,
        body: doc.body,
        created_at: doc.created_at&.iso8601,
        updated_at: doc.updated_at&.iso8601
      }
      body[:body_embedding] = embedding if embedding

      ELASTICSEARCH_CLIENT.index(
        index: TEST_INDEX_NAME,
        id: doc.id.to_s,
        routing: doc.id.to_s,
        body: body,
        refresh: true
      )
    end

    def index_project_membership(doc_id, project_id, project_name)
      membership_id = "#{doc_id}_#{project_id}"

      ELASTICSEARCH_CLIENT.index(
        index: TEST_INDEX_NAME,
        id: membership_id,
        routing: doc_id.to_s,
        body: {
          doc_project_join: { name: 'project_membership', parent: doc_id.to_s },
          project_id: project_id,
          project_name: project_name
        },
        refresh: true
      )
    end

    def delete_all_documents
      ELASTICSEARCH_CLIENT.delete_by_query(
        index: TEST_INDEX_NAME,
        body: { query: { match_all: {} } },
        refresh: true
      )
    rescue Elastic::Transport::Transport::Errors::NotFound
      # Index doesn't exist
    end

    def document_count
      response = ELASTICSEARCH_CLIENT.count(index: TEST_INDEX_NAME)
      response['count']
    rescue StandardError
      0
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    if ElasticsearchTestHelper.elasticsearch_available?
      ElasticsearchTestHelper.setup_test_index
    end
  end

  config.after(:suite) do
    if ElasticsearchTestHelper.elasticsearch_available?
      ElasticsearchTestHelper.teardown_test_index
    end
  end

  config.around(:each, :elasticsearch) do |example|
    if ElasticsearchTestHelper.elasticsearch_available?
      # Clean up before each test
      ElasticsearchTestHelper.delete_all_documents

      # Temporarily override the index alias constant for tests
      original_alias = ELASTICSEARCH_INDEX_ALIAS
      silence_warnings { Object.const_set(:ELASTICSEARCH_INDEX_ALIAS, ElasticsearchTestHelper::TEST_INDEX_ALIAS) }

      example.run

      silence_warnings { Object.const_set(:ELASTICSEARCH_INDEX_ALIAS, original_alias) }
    else
      skip 'Elasticsearch not available'
    end
  end
end

def silence_warnings
  old_verbose = $VERBOSE
  $VERBOSE = nil
  yield
ensure
  $VERBOSE = old_verbose
end
