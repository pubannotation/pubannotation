# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /docs.json content type authentication', type: :request do
  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
    allow(Elasticsearch::IndexQueue).to receive(:update_embedding)
  end

  let(:password) { 'password' }
  let(:user) { create(:user, password: password).tap(&:confirm) }
  let(:project) { create(:project, user: user) }

  let(:doc_params) do
    {
      project_id: project.name,
      doc: { text: 'test', sourcedb: 'Example', sourceid: '001' },
      commit: 'Create'
    }
  end

  let(:basic_auth_headers) do
    { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials(user.email, password) }
  end

  context 'with Content-Type: application/json' do
    it 'authenticates via Basic auth and creates a doc' do
      expect {
        post '/docs.json',
             params: doc_params.to_json,
             headers: basic_auth_headers.merge('CONTENT_TYPE' => 'application/json')
      }.to change(Doc, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'rejects request without Basic auth credentials' do
      expect {
        post '/docs.json',
             params: doc_params.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }
      }.not_to change(Doc, :count)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'with Content-Type: application/jsonrequest' do
    it 'does not accept Basic auth and rejects without session auth' do
      expect {
        post '/docs.json',
             params: doc_params.to_json,
             headers: { 'CONTENT_TYPE' => 'application/jsonrequest' }
      }.not_to change(Doc, :count)
    end
  end
end
