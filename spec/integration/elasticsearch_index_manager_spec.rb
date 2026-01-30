# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Elasticsearch::IndexManager, :elasticsearch do
  let(:manager) { described_class.new }
  let(:test_version) { 998 }  # Different from helper's 999 to avoid conflicts
  let(:test_index_name) { "pubannotation_docs_v#{test_version}" }

  after do
    # Clean up test index
    begin
      ELASTICSEARCH_CLIENT.indices.delete(index: test_index_name)
    rescue Elastic::Transport::Transport::Errors::NotFound
      # Index doesn't exist, that's fine
    end
  end

  describe '#create_index' do
    it 'creates an index with correct mappings' do
      result = manager.create_index(version: test_version)

      expect(result['acknowledged']).to be true
      expect(manager.index_exists?(test_index_name)).to be true
    end

    it 'returns existing flag if index already exists' do
      manager.create_index(version: test_version)
      result = manager.create_index(version: test_version)

      expect(result[:existing]).to be true
    end

    it 'includes dense_vector mapping for embeddings' do
      manager.create_index(version: test_version)

      mapping = ELASTICSEARCH_CLIENT.indices.get_mapping(index: test_index_name)
      properties = mapping.dig(test_index_name, 'mappings', 'properties')

      expect(properties['body_embedding']['type']).to eq('dense_vector')
      expect(properties['body_embedding']['dims']).to eq(768)
    end
  end

  describe '#delete_index' do
    before do
      manager.create_index(version: test_version)
    end

    it 'deletes the index' do
      expect(manager.index_exists?(test_index_name)).to be true

      manager.delete_index(version: test_version)

      expect(manager.index_exists?(test_index_name)).to be false
    end

    it 'handles non-existent index gracefully' do
      manager.delete_index(version: test_version)
      result = manager.delete_index(version: test_version)

      expect(result[:not_found]).to be true
    end
  end

  describe '#index_exists?' do
    it 'returns true for existing index' do
      manager.create_index(version: test_version)

      expect(manager.index_exists?(test_index_name)).to be true
    end

    it 'returns false for non-existing index' do
      expect(manager.index_exists?('nonexistent_index_12345')).to be false
    end
  end

  describe '#switch_alias' do
    let(:test_alias) { 'test_alias_for_switching' }

    before do
      manager.create_index(version: test_version)

      # Stub the alias name for this test
      allow(Elasticsearch::Config).to receive(:index_alias).and_return(test_alias)
    end

    after do
      begin
        ELASTICSEARCH_CLIENT.indices.delete_alias(index: test_index_name, name: test_alias)
      rescue Elastic::Transport::Transport::Errors::NotFound
        # Alias doesn't exist
      end
    end

    it 'points alias to the specified index' do
      manager.switch_alias(to_version: test_version)

      aliases = manager.get_indices_for_alias(test_alias)
      expect(aliases).to include(test_index_name)
    end

    it 'raises error if target index does not exist' do
      expect {
        manager.switch_alias(to_version: 12345)
      }.to raise_error(ArgumentError, /does not exist/)
    end
  end

  describe '#index_stats' do
    before do
      manager.create_index(version: test_version)

      # Index a document
      ELASTICSEARCH_CLIENT.index(
        index: test_index_name,
        id: '1',
        body: { body: 'Test document' },
        refresh: true
      )
    end

    it 'returns document count' do
      stats = manager.index_stats(version: test_version)

      expect(stats[:docs_count]).to eq(1)
    end

    it 'returns human-readable size' do
      stats = manager.index_stats(version: test_version)

      expect(stats[:store_size_human]).to match(/\d+(\.\d+)?\s+(B|KB|MB|GB)/)
    end

    it 'handles non-existent index' do
      stats = manager.index_stats(version: 12345)

      expect(stats[:error]).to eq('Index not found')
    end
  end

  describe '#cluster_health' do
    it 'returns cluster status' do
      health = manager.cluster_health

      expect(health['status']).to be_in(['green', 'yellow', 'red'])
      expect(health['cluster_name']).to be_present
    end
  end

  describe '#refresh' do
    before do
      manager.create_index(version: test_version)
    end

    it 'refreshes the index without error' do
      expect { manager.refresh(version: test_version) }.not_to raise_error
    end
  end

  describe '#version_from_index' do
    it 'extracts version number from index name' do
      expect(manager.version_from_index('pubannotation_docs_v1')).to eq(1)
      expect(manager.version_from_index('pubannotation_docs_v123')).to eq(123)
    end

    it 'returns nil for invalid index name' do
      expect(manager.version_from_index('other_index')).to be_nil
      expect(manager.version_from_index(nil)).to be_nil
    end
  end
end
