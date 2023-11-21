require 'rails_helper'

RSpec.describe 'TermSearch::DocsController', type: :request do
  describe 'GET /term_search/docs' do
    let!(:docs) { create_list(:doc, 3) }

    context 'when requesting JSON format' do
      before { get term_search_docs_path, as: :json }

      it 'returns http success' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type as JSON' do
        expect(response.media_type).to eq('application/json')
      end

      it 'returns correct number of docs' do
        json_response = JSON.parse(response.body)
        expect(json_response.size).to eq(docs.size)
      end

      it 'returns docs in correct format' do
        json_response = JSON.parse(response.body)

        expect(json_response).to be_an_instance_of(Array)
        expect(json_response.length).to eq(docs.length)
        expect(json_response[0]).to eq(docs[0].to_list_hash.stringify_keys)
      end
    end

    context 'when requesting TSV format' do
      before { get "#{term_search_docs_path}.tsv" }

      it 'returns http success' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns content type as TSV' do
        expect(response.media_type).to eq('text/tab-separated-values')
      end

      it 'returns correct format of docs' do
        expect(response.body.split("\n").second).to eq(docs[0].to_list_hash.values.join("\t"))
      end
    end
  end
end
