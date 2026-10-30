# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Updating a document from its source', type: :request do
  include Devise::Test::IntegrationHelpers
  let(:user) { create(:user, root: true) }
  let!(:doc) { create(:doc, sourcedb: 'PMC', sourceid: '123', body: 'Hello world') }
  let(:path) { '/docs/sourcedb/PMC/sourceid/123/uptodate' }

  before do
    user.confirm
    sign_in user
  end

  it 'fetches the source document and revises the stored text and annotations' do
    denotation = create(:denotation, doc: doc, begin: 6, end: 11)
    expect(DocumentFetcher).to receive(:fetch).with('PMC', ['123']).and_return([[{ text: 'Hello big world' }], []])

    get path

    expect(response).to redirect_to('/docs/sourcedb/PMC/sourceid/123')
    expect(flash[:notice]).to eq('The document PMC:123 was successfully updated.')
    expect(doc.reload.body).to eq('Hello big world')
    expect([denotation.reload.begin, denotation.end]).to eq([10, 15])
  end

  it 'reports source errors without modifying the document' do
    allow(DocumentFetcher).to receive(:fetch).and_return([[], [{ body: 'Not found' }]])

    get path

    expect(response).to be_redirect
    expect(flash[:notice]).to eq('Could not sequence the document, PMC:123: Not found')
    expect(doc.reload.body).to eq('Hello world')
  end

  it 'rejects multiple source documents without modifying the document' do
    allow(DocumentFetcher).to receive(:fetch).and_return([[{ text: 'First' }, { text: 'Second' }], []])

    get path

    expect(response).to be_redirect
    expect(flash[:notice]).to eq('Could not sequence the document, PMC:123')
    expect(doc.reload.body).to eq('Hello world')
  end

  it 'reports an empty result even when there are no source messages' do
    allow(DocumentFetcher).to receive(:fetch).and_return([[], []])

    get path

    expect(response).to be_redirect
    expect(flash[:notice]).to eq('Could not sequence the document, PMC:123')
    expect(doc.reload.body).to eq('Hello world')
  end

  context 'as a non-root user' do
    let(:user) { create(:user, root: false) }

    it 'does not fetch or revise the document' do
      expect(DocumentFetcher).not_to receive(:fetch)

      get path

      expect(response).to have_http_status(:forbidden)
      expect(doc.reload.body).to eq('Hello world')
    end
  end
end
