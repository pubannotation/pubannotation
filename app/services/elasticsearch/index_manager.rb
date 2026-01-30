# frozen_string_literal: true

module Elasticsearch
  # IndexManager handles Elasticsearch index lifecycle operations
  # including creation, deletion, alias management, and zero-downtime migrations
  #
  # Usage:
  #   manager = Elasticsearch::IndexManager.new
  #   manager.create_index(version: 1)
  #   manager.switch_alias(to_version: 1)
  #   manager.reindex(from_version: 1, to_version: 2)
  #
  class IndexManager
    MAPPING_PATH = Rails.root.join('config', 'elasticsearch', 'mappings', 'docs_v1.json')

    attr_reader :client

    def initialize(client: nil)
      @client = client || ELASTICSEARCH_CLIENT
    end

    # Create a new index with the specified version
    # @param version [Integer] Index version number
    # @param mapping_path [String] Path to mapping JSON file (optional)
    # @return [Hash] Elasticsearch response
    def create_index(version:, mapping_path: nil)
      index_name = Elasticsearch::Config.index_name(version)
      mapping_path ||= MAPPING_PATH

      raise ArgumentError, "Mapping file not found: #{mapping_path}" unless File.exist?(mapping_path)

      settings_and_mappings = JSON.parse(File.read(mapping_path))

      if index_exists?(index_name)
        Rails.logger.info "[ES] Index #{index_name} already exists, skipping creation"
        return { acknowledged: true, existing: true }
      end

      Rails.logger.info "[ES] Creating index: #{index_name}"
      client.indices.create(
        index: index_name,
        body: settings_and_mappings
      )
    end

    # Delete an index by version
    # @param version [Integer] Index version number
    # @return [Hash] Elasticsearch response
    def delete_index(version:)
      index_name = Elasticsearch::Config.index_name(version)

      unless index_exists?(index_name)
        Rails.logger.info "[ES] Index #{index_name} does not exist, nothing to delete"
        return { acknowledged: true, not_found: true }
      end

      Rails.logger.info "[ES] Deleting index: #{index_name}"
      client.indices.delete(index: index_name)
    end

    # Check if an index exists
    # @param index_name [String] Full index name
    # @return [Boolean]
    def index_exists?(index_name)
      client.indices.exists?(index: index_name)
    end

    # Switch the alias to a new index version (atomic operation)
    # Removes alias from all old indices and points to new index
    # @param to_version [Integer] Target index version
    # @return [Hash] Elasticsearch response
    def switch_alias(to_version:)
      alias_name = Elasticsearch::Config.index_alias
      new_index = Elasticsearch::Config.index_name(to_version)

      raise ArgumentError, "Target index #{new_index} does not exist" unless index_exists?(new_index)

      actions = []

      # Remove alias from any existing indices
      current_indices = get_indices_for_alias(alias_name)
      current_indices.each do |old_index|
        actions << { remove: { index: old_index, alias: alias_name } }
      end

      # Add alias to the new index
      actions << { add: { index: new_index, alias: alias_name } }

      Rails.logger.info "[ES] Switching alias #{alias_name} to #{new_index}"
      client.indices.update_aliases(body: { actions: actions })
    end

    # Add alias to an index without removing from others
    # @param version [Integer] Index version
    # @return [Hash] Elasticsearch response
    def add_alias(version:)
      alias_name = Elasticsearch::Config.index_alias
      index_name = Elasticsearch::Config.index_name(version)

      raise ArgumentError, "Index #{index_name} does not exist" unless index_exists?(index_name)

      Rails.logger.info "[ES] Adding alias #{alias_name} to #{index_name}"
      client.indices.put_alias(index: index_name, name: alias_name)
    end

    # Remove alias from an index
    # @param version [Integer] Index version
    # @return [Hash] Elasticsearch response
    def remove_alias(version:)
      alias_name = Elasticsearch::Config.index_alias
      index_name = Elasticsearch::Config.index_name(version)

      Rails.logger.info "[ES] Removing alias #{alias_name} from #{index_name}"
      client.indices.delete_alias(index: index_name, name: alias_name)
    end

    # Get all indices that have the main alias
    # @param alias_name [String] Alias name (defaults to main alias)
    # @return [Array<String>] List of index names
    def get_indices_for_alias(alias_name = nil)
      alias_name ||= Elasticsearch::Config.index_alias

      begin
        response = client.indices.get_alias(name: alias_name)
        response.keys
      rescue Elastic::Transport::Transport::Errors::NotFound
        []
      end
    end

    # Get the current active index (the one the alias points to)
    # @return [String, nil] Current index name or nil if no alias configured
    def current_index
      indices = get_indices_for_alias
      indices.first
    end

    # Get the version number from an index name
    # @param index_name [String] Full index name
    # @return [Integer, nil] Version number or nil if not parseable
    def version_from_index(index_name)
      return nil unless index_name

      match = index_name.match(/pubannotation_docs_v(\d+)/)
      match ? match[1].to_i : nil
    end

    # Get current version number
    # @return [Integer, nil]
    def current_version
      version_from_index(current_index)
    end

    # Reindex from one index to another using Elasticsearch's reindex API
    # @param from_version [Integer] Source index version
    # @param to_version [Integer] Destination index version
    # @param wait_for_completion [Boolean] Wait for reindex to complete
    # @return [Hash] Elasticsearch response
    def reindex(from_version:, to_version:, wait_for_completion: true)
      source_index = Elasticsearch::Config.index_name(from_version)
      dest_index = Elasticsearch::Config.index_name(to_version)

      raise ArgumentError, "Source index #{source_index} does not exist" unless index_exists?(source_index)
      raise ArgumentError, "Destination index #{dest_index} does not exist" unless index_exists?(dest_index)

      Rails.logger.info "[ES] Reindexing from #{source_index} to #{dest_index}"
      client.reindex(
        body: {
          source: { index: source_index },
          dest: { index: dest_index }
        },
        wait_for_completion: wait_for_completion
      )
    end

    # Get index statistics
    # @param version [Integer, nil] Index version (nil for alias)
    # @return [Hash] Index stats including doc count, size
    def index_stats(version: nil)
      index_name = version ? Elasticsearch::Config.index_name(version) : Elasticsearch::Config.index_alias

      begin
        stats = client.indices.stats(index: index_name)
        primaries = stats.dig('_all', 'primaries') || {}

        {
          index: index_name,
          docs_count: primaries.dig('docs', 'count') || 0,
          docs_deleted: primaries.dig('docs', 'deleted') || 0,
          store_size: primaries.dig('store', 'size_in_bytes') || 0,
          store_size_human: format_bytes(primaries.dig('store', 'size_in_bytes') || 0)
        }
      rescue Elastic::Transport::Transport::Errors::NotFound
        { index: index_name, error: 'Index not found' }
      end
    end

    # Refresh the index to make recent changes searchable
    # @param version [Integer, nil] Index version (nil for alias)
    def refresh(version: nil)
      index_name = version ? Elasticsearch::Config.index_name(version) : Elasticsearch::Config.index_alias
      client.indices.refresh(index: index_name)
    end

    # Update index settings (e.g., refresh_interval)
    # @param version [Integer] Index version
    # @param settings [Hash] Settings to update
    def update_settings(version:, settings:)
      index_name = Elasticsearch::Config.index_name(version)
      client.indices.put_settings(index: index_name, body: settings)
    end

    # Disable refresh temporarily for bulk operations
    # @param version [Integer] Index version
    def disable_refresh(version:)
      update_settings(version: version, settings: { refresh_interval: '-1' })
    end

    # Enable refresh after bulk operations
    # @param version [Integer] Index version
    # @param interval [String] Refresh interval (default: '1s')
    def enable_refresh(version:, interval: '1s')
      update_settings(version: version, settings: { refresh_interval: interval })
    end

    # Cluster health check
    # @return [Hash] Cluster health status
    def cluster_health
      client.cluster.health
    end

    private

    def format_bytes(bytes)
      return '0 B' if bytes.nil? || bytes == 0

      units = %w[B KB MB GB TB]
      exp = (Math.log(bytes) / Math.log(1024)).to_i
      exp = units.length - 1 if exp > units.length - 1

      format('%.2f %s', bytes.to_f / (1024**exp), units[exp])
    end
  end
end
