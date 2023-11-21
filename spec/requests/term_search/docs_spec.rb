require 'rails_helper'

RSpec.describe 'TermSearch::DocsController', type: :request do
  describe 'GET /term_search/docs' do
    let!(:docs) { create_list(:doc, 3) }

    context 'when requesting JSON format' do
      it 'returns docs in JSON format' do
        get term_search_docs_path, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response).to be_an_instance_of(Array)
        expect(json_response.length).to eq(docs.length)
        expect(json_response[0]).to eq(docs[0].to_list_hash.stringify_keys)
      end
    end

    context 'when requesting TSV format' do
      it 'returns docs in TSV format' do
        get "#{term_search_docs_path}.tsv"

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('text/tab-separated-values')
        expect(response.body.split("\n").second).to eq(docs[0].to_list_hash.values.join("\t"))
      end
    end
  end
end
