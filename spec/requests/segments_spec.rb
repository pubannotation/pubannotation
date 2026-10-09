# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Editing segment text', type: :request do
  include Devise::Test::IntegrationHelpers

  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
  end

  let(:root_user) { create(:user, root: true).tap(&:confirm) }
  let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
  let(:doc) { create(:doc, body: 'Hello world', medium:) }
  let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

  context 'as a root user' do
    before { sign_in root_user }

    describe 'GET /docs/:doc_id/segments' do
      it 'lists the segments with their times, each with an Edit button for the dialog' do
        get "/docs/#{doc.id}/segments"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('0:00.300', 'Hello', 'world')
        expect(response.body).to include(%(data-url="/docs/#{doc.id}/segments/1"), 'data-text="world"')
        expect(response.body).to include('<dialog id="segment-dialog" data-open-on-load="false">')
      end
    end

    describe 'PATCH /docs/:doc_id/segments/:index' do
      it "updates the segment's text and the doc's body, then goes back to the list" do
        patch "/docs/#{doc.id}/segments/1", params: { segment: { text: 'there' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(media_transcript.reload.segments.last['text']).to eq('there')
        expect(doc.reload.body).to eq('Hello there')
      end

      it 'shows the error, reopening the dialog with the entered text, when the update is rejected' do
        patch "/docs/#{doc.id}/segments/1", params: { segment: { text: ' ' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Text is missing.', 'data-open-on-load="true"', ' </textarea>')
        expect(response.body).to include(%(action="/docs/#{doc.id}/segments/1"))
        expect(media_transcript.reload.segments.last['text']).to eq('world')
      end

      it 'responds with not found for an index with no segment' do
        patch "/docs/#{doc.id}/segments/2", params: { segment: { text: 'there' } }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'the doc detail page' do
      it 'links to the segment list' do
        get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

        expect(response.body).to include("href=\"/docs/#{doc.id}/segments\"")
      end

      it 'has no link for a doc with an image' do
        image_doc = create(:doc, medium: create(:medium, media_type: :image, content_type: 'image/png'))
        create(:media_transcript, medium: image_doc.medium, doc: image_doc, text: 'A caption.', segments: [])

        get "/docs/sourcedb/#{image_doc.sourcedb}/sourceid/#{image_doc.sourceid}"

        expect(response.body).not_to include("/docs/#{image_doc.id}/segments")
      end
    end

    it 'responds with not found for a doc with an image' do
      image_doc = create(:doc, medium: create(:medium, media_type: :image, content_type: 'image/png'))

      get "/docs/#{image_doc.id}/segments"

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'as a user who cannot update the doc' do
    before { sign_in create(:user).tap(&:confirm) }

    it 'forbids the segment list and the update' do
      get "/docs/#{doc.id}/segments"
      expect(response).to have_http_status(:forbidden)

      patch "/docs/#{doc.id}/segments/1", params: { segment: { text: 'there' } }
      expect(response).to have_http_status(:forbidden)
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'has no link on the doc detail page' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).not_to include("/docs/#{doc.id}/segments")
    end
  end

  context 'as a root user who cannot access media' do
    before do
      sign_in root_user
      allow_any_instance_of(User).to receive(:can_access_media?).and_return(false)
    end

    it 'forbids the segment list' do
      get "/docs/#{doc.id}/segments"

      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'requires signing in' do
    get "/docs/#{doc.id}/segments"

    expect(response).to redirect_to('/users/sign_in')
  end
end
