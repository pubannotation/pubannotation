# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentSearch do
  let(:embedding) { [0.1, 0.2] }

  before do
    allow(EmbeddingService).to receive(:generate).with('tumor').and_return(embedding)
  end

  it 'merges hybrid results, preserves highlights, and loads records through Doc' do
    keyword_hit = { '_id' => '1', '_score' => 2.0, 'highlight' => { 'body' => ['<em>tumor</em>'] } }
    semantic_hit = { '_id' => '2', '_score' => 0.9, '_source' => { 'body' => 'tumor suppressor' } }
    expect(ELASTICSEARCH_CLIENT).to receive(:search).with(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: hash_including(query: anything)
    ).ordered.and_return({ 'hits' => { 'hits' => [keyword_hit] } })
    expect(ELASTICSEARCH_CLIENT).to receive(:search).with(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: hash_including(knn: hash_including(query_vector: embedding))
    ).ordered.and_return({ 'hits' => { 'hits' => [semantic_hit] } })

    results = DocumentSearch.hybrid_search('tumor', page: 1, per: 5)

    expect(results).to have_attributes(model_class: Doc, total: 2, page: 1, per: 5)
    expect(results.map(&:id)).to eq([1, 2])
    expect(results.map { |hit| hit.highlight.body }).to eq([
      ['<em>tumor</em>'], ['<em>tumor</em> suppressor']
    ])
    expect(results.map(&:rrf_score)).to eq([1.0 / 61, 1.0 / 61])
  end

  it 'paginates kNN results and loads records through Doc' do
    expect(ELASTICSEARCH_CLIENT).to receive(:search).with(
      index: ELASTICSEARCH_INDEX_ALIAS,
      body: hash_including(
        knn: hash_including(query_vector: embedding, filter: [
          { term: { 'doc_project_join' => 'doc' } }, { term: { sourcedb: 'PMC' } }
        ]),
        from: 5, size: 5
      )
    ).and_return({ 'hits' => { 'total' => 6, 'hits' => [
      { '_id' => '2', '_source' => { 'body' => 'tumor suppressor' } }
    ] } })

    results = DocumentSearch.knn_search('tumor', sourcedb: 'PMC', page: 2, per: 5)

    expect(results).to have_attributes(model_class: Doc, total: 6, page: 2, per: 5)
    expect(results.first.highlight.body).to eq(['<em>tumor</em> suppressor'])
  end
end
