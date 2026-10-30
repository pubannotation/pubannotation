# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentSearch, 'Elasticsearch search', type: :model do
  let(:response) { { 'hits' => { 'hits' => [], 'total' => 0 } } }

  it 'returns empty results without contacting Elasticsearch for blank keywords' do
    expect(ELASTICSEARCH_CLIENT).not_to receive(:search)
    expect(EmbeddingService).not_to receive(:generate)

    results = DocumentSearch.search_by_elasticsearch(' ', nil, nil, 2, 5, semantic: true)

    expect(results).to be_empty
    expect(results).to have_attributes(model_class: Doc, total: 0)
  end

  it 'preserves filters, pagination, and highlighting for text search' do
    project = build_stubbed(:project)
    expect(ELASTICSEARCH_CLIENT).to receive(:search).with(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: {
        query: { bool: {
          must: [{ match: { body: { query: 'tumor' } } }],
          filter: [
            { term: { sourcedb: 'PMC' } },
            { has_child: { type: 'project_membership', query: { term: { project_id: project.id } } } },
            { term: { 'doc_project_join' => 'doc' } }
          ]
        } },
        highlight: { fields: { body: {} } },
        from: 5,
        size: 5
      }
    ).and_return(response)

    results = DocumentSearch.search_by_elasticsearch('tumor', project, 'PMC', 2, 5)

    expect(results).to have_attributes(response: response, model_class: Doc)
  end

  it 'logs a search failure and returns empty results' do
    allow(ELASTICSEARCH_CLIENT).to receive(:search).and_raise(StandardError, 'Search unavailable')
    expect(Rails.logger).to receive(:error).with('[ES Search] Error: Search unavailable')

    results = DocumentSearch.search_by_elasticsearch('tumor', nil, nil, 1, 10)

    expect(results).to be_empty
    expect(results.total).to eq(0)
  end

  it 'selects hybrid search when semantic search is requested' do
    expected = SearchResults.new(response, Doc, page: 2, per: 5)
    expect(DocumentSearch).to receive(:hybrid_search).with('tumor', project: nil, sourcedb: 'PMC', page: 2, per: 5).and_return(expected)

    expect(DocumentSearch.search_by_elasticsearch('tumor', nil, 'PMC', 2, 5, semantic: true)).to equal(expected)
  end

  %i[hybrid_search knn_search].each do |method|
    it "falls back to text search when #{method} cannot obtain an embedding" do
      allow(EmbeddingService).to receive(:generate).with('tumor').and_return(nil)
      expect(ELASTICSEARCH_CLIENT).to receive(:search).with(
        index: ELASTICSEARCH_INDEX_ALIAS,
        body: hash_including(
          query: hash_including(bool: hash_including(must: [{ match: { body: { query: 'tumor' } } }])),
          from: 5, size: 5
        )
      ).and_return(response)

      results = DocumentSearch.public_send(method, 'tumor', sourcedb: 'PMC', page: 2, per: 5)

      expect(results).to have_attributes(model_class: Doc)
    end
  end
end
