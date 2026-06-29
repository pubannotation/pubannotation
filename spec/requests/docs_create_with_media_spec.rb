# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'POST /docs.json', type: :request do
  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
    allow(Elasticsearch::IndexQueue).to receive(:update_embedding)
  end

  let(:password) { 'password' }
  let(:user) do
    create(:user, password: password).tap(&:confirm)
  end
  let(:project) { create(:project, user: user) }
  let(:medium) { create(:medium) }

  let(:headers) do
    {
      'HTTP_AUTHORIZATION' =>
        ActionController::HttpAuthentication::Basic.encode_credentials(
          user.email,
          password
        )
    }
  end

  let(:params) do
    {
      project_id: project.name,
      doc: {
        text: 'doctor findings',
        sourcedb: 'Example',
        sourceid: '001'
      },
      commit: 'Create'
    }
  end

  it 'creates a doc linked to the specified medium' do
    post '/docs.json',
         params: params.merge(
           media: {
             sourcedb: medium.sourcedb,
             sourceid: medium.sourceid
           }
         ),
         headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.medium).to eq(medium)
  end

  it 'creates a doc without a medium when media is omitted' do
    post '/docs.json', params: params, headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.medium).to be_nil
  end

  it 'returns an error when the specified medium does not exist' do
    post '/docs.json',
         params: params.merge(
           media: {
             sourcedb: 'NonExistentDB',
             sourceid: 'nonexistent-001'
           }
         ),
         headers: headers

    expect(response).to have_http_status(:unprocessable_content)
  end
end
