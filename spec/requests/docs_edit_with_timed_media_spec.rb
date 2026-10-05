# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Editing a doc with audio or video', type: :request do
  include Devise::Test::IntegrationHelpers

  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
    allow(Elasticsearch::IndexQueue).to receive(:update_embedding)
  end

  let(:root_user) { create(:user, root: true).tap(&:confirm) }
  let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
  let(:doc) { create(:doc, body: 'Hello world', medium:) }

  before { sign_in root_user }

  context 'when the doc has an audio medium' do
    before do
      MediaTranscript.create!(medium:, doc:, segments: [{ 'text' => 'Hello world', 'start_ms' => 0, 'end_ms' => 1000 }])
    end

    it 'shows the edit page with the text read-only' do
      get edit_doc_path(doc)

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<textarea[^>]*name="doc\[text\]"[^>]*readonly="readonly"/)
      expect(response.body).to include('The text cannot be changed, since it is tied to the audio or video.')
    end

    it 'still accepts changes to the other fields, submitted with the unchanged text' do
      put doc_path(doc, format: :json), params: { doc: { text: 'Hello world', source: 'https://example.com/changed' } }

      expect(response).to have_http_status(:no_content)
      expect(doc.reload.source).to eq('https://example.com/changed')
    end

    it 'rejects a body change' do
      put doc_path(doc, format: :json), params: { doc: { text: 'Changed body' } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(doc.reload.body).to eq('Hello world')
    end
  end

  context 'when the doc has an image medium with a media transcript' do
    let(:medium) { create(:medium, media_type: :image, content_type: 'image/png') }

    before { MediaTranscript.create!(medium:, doc:, text: 'Hello world') }

    it 'shows the edit page with the text editable' do
      get edit_doc_path(doc)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(/<textarea[^>]*readonly/)
    end

    it 'accepts a body change' do
      put doc_path(doc, format: :json), params: { doc: { text: 'Changed body' } }

      expect(response).to have_http_status(:no_content)
      expect(doc.reload.body).to eq('Changed body')
    end
  end
end
