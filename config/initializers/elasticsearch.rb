# frozen_string_literal: true

# Elasticsearch 8.x Client Configuration
#
# Environment Variables:
#   ELASTICSEARCH_URL - Elasticsearch server URL (default: http://localhost:9200)
#   ELASTICSEARCH_API_KEY - API key for authentication (optional, for production)
#
# Usage:
#   ELASTICSEARCH_CLIENT.search(index: 'pubannotation_docs', body: {...})
#   ELASTICSEARCH_CLIENT.bulk(body: [...])

require 'elasticsearch'

module Elasticsearch
  module Config
    INDEX_ALIAS = 'pubannotation_docs'
    INDEX_PREFIX = 'pubannotation_docs_v'

    class << self
      def client
        @client ||= build_client
      end

      def url
        ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200')
      end

      def api_key
        ENV['ELASTICSEARCH_API_KEY']
      end

      def index_alias
        INDEX_ALIAS
      end

      def index_name(version)
        "#{INDEX_PREFIX}#{version}"
      end

      private

      def build_client
        options = {
          url: url,
          log: false,
          transport_options: {
            request: { timeout: 60 }
          }
        }

        # Add API key authentication if configured (recommended for production)
        options[:api_key] = api_key if api_key.present?

        ::Elasticsearch::Client.new(options)
      end
    end
  end
end

# Global constant for easy access
ELASTICSEARCH_CLIENT = Elasticsearch::Config.client
ELASTICSEARCH_INDEX_ALIAS = Elasticsearch::Config::INDEX_ALIAS
