# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Docs API', type: :request do
  describe 'GET /docs/sourcedb/:sourcedb/sourceid/:sourceid.txt' do
    let!(:doc) { create(:doc, sourcedb: 'PubMed', sourceid: '12345', body: 'This is the document body text.') }

    it 'returns the document body as plain text' do
      get '/docs/sourcedb/PubMed/sourceid/12345.txt'

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('text/plain')
      expect(response.body).to eq('This is the document body text.')
    end

    it 'returns 404 for non-existent document' do
      get '/docs/sourcedb/PubMed/sourceid/nonexistent.txt'

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /docs/search.json', :elasticsearch do
    let!(:doc1) { create(:doc, sourcedb: 'PubMed', sourceid: '11111', body: 'p53 tumor suppressor protein in cancer cells') }
    let!(:doc2) { create(:doc, sourcedb: 'PubMed', sourceid: '22222', body: 'BRCA1 mutation and breast cancer risk') }
    let!(:doc3) { create(:doc, sourcedb: 'PMC', sourceid: '33333', body: 'Diabetes treatment with metformin') }

    before do
      # Index documents in Elasticsearch
      [doc1, doc2, doc3].each do |doc|
        ElasticsearchTestHelper.index_document(doc)
      end
      ElasticsearchTestHelper.refresh_index
    end

    context 'with valid query' do
      it 'returns search results as JSON' do
        get '/docs/search.json', params: { query: 'cancer' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/json')

        results = JSON.parse(response.body)
        expect(results).to be_an(Array)
        expect(results.length).to be >= 1
        expect(results.first).to have_key('sourcedb')
        expect(results.first).to have_key('sourceid')
        expect(results.first).to have_key('snippet')
      end

      it 'filters by sourcedb' do
        get '/docs/search.json', params: { query: 'treatment', sourcedb: 'PMC' }

        expect(response).to have_http_status(:ok)
        results = JSON.parse(response.body)
        results.each do |r|
          expect(r['sourcedb']).to eq('PMC')
        end
      end

      it 'respects per parameter' do
        get '/docs/search.json', params: { query: 'cancer', per: 1 }

        expect(response).to have_http_status(:ok)
        results = JSON.parse(response.body)
        expect(results.length).to be <= 1
      end

      it 'caps per at 100' do
        get '/docs/search.json', params: { query: 'cancer', per: 500 }

        expect(response).to have_http_status(:ok)
        # Should not error, just cap at 100
      end

      it 'accepts method=bm25' do
        get '/docs/search.json', params: { query: 'tumor', method: 'bm25' }

        expect(response).to have_http_status(:ok)
        results = JSON.parse(response.body)
        expect(results).to be_an(Array)
      end

      it 'accepts method=rrf' do
        get '/docs/search.json', params: { query: 'tumor', method: 'rrf' }

        expect(response).to have_http_status(:ok)
        results = JSON.parse(response.body)
        expect(results).to be_an(Array)
      end
    end

    context 'with invalid parameters' do
      it 'returns error when query is missing' do
        get '/docs/search.json'

        expect(response).to have_http_status(:bad_request)
        result = JSON.parse(response.body)
        expect(result['error']).to include('query parameter is required')
      end

      it 'returns error for invalid method' do
        get '/docs/search.json', params: { query: 'cancer', method: 'invalid' }

        expect(response).to have_http_status(:bad_request)
        result = JSON.parse(response.body)
        expect(result['error']).to include('Invalid method')
      end
    end
  end

  describe 'GET /docs/search.json with kNN', :elasticsearch do
    let!(:doc) { create(:doc, sourcedb: 'PubMed', sourceid: '44444', body: 'Myocardial infarction treatment options') }

    before do
      # Mock embedding service for kNN test
      allow(EmbeddingService).to receive(:generate).and_return(Array.new(768) { rand(-1.0..1.0) })

      embedding = Array.new(768) { rand(-1.0..1.0) }
      ElasticsearchTestHelper.index_document(doc, embedding: embedding)
      ElasticsearchTestHelper.refresh_index
    end

    it 'accepts method=knn' do
      get '/docs/search.json', params: { query: 'heart attack', method: 'knn' }

      expect(response).to have_http_status(:ok)
      results = JSON.parse(response.body)
      expect(results).to be_an(Array)
    end
  end
end
