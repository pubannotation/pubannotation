# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'The segments page', type: :request do
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
      it 'lists the segments with their times' do
        get "/docs/#{doc.id}/segments"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('0:00.300', 'Hello', 'world')
      end

      it 'notes a non-speech segment as not in the text' do
        media_transcript.update_column(:segments, [{ 'text' => '(music)', 'start_ms' => 0, 'end_ms' => 300 },
                                                   { 'text' => 'Hello world', 'start_ms' => 300, 'end_ms' => 600 }])

        get "/docs/#{doc.id}/segments"

        expect(response.body.scan('(not in the text)').size).to eq(1)
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

    it 'forbids the segment list' do
      get "/docs/#{doc.id}/segments"

      expect(response).to have_http_status(:forbidden)
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
