# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'The segment split editor', type: :request do
  include Devise::Test::IntegrationHelpers

  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
  end

  let(:medium) do
    create(:medium, media_type: :audio, content_type: 'audio/mpeg').tap do |medium|
      medium.file.attach(io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')),
                         filename: 'test_audio.mp3', content_type: 'audio/mpeg')
    end
  end
  let(:doc) { create(:doc, body: 'Hello world', medium:) }
  let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

  context 'as a user who can edit the segments' do
    before { sign_in create(:user, root: true).tap(&:confirm) }

    it 'shows the media, a Split here button, and the segments for the page to render' do
      get "/docs/#{doc.id}/segment_split/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="media-player"', 'id="split-here"')
      expect(response.body).to include(ERB::Util.html_escape(media_transcript.segments.to_json))
    end

    it 'links to it from the segment list' do
      get "/docs/#{doc.id}/segments"

      expect(response.body).to include(%(href="/docs/#{doc.id}/segment_split/edit"))
    end

    it 'responds with not found for a doc with no segments' do
      image_doc = create(:doc, medium: create(:medium, media_type: :image, content_type: 'image/png'))

      get "/docs/#{image_doc.id}/segment_split/edit"

      expect(response).to have_http_status(:not_found)
    end

    it 'responds with not found for a doc that does not exist' do
      get '/docs/0/segment_split/edit'

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'as a user who can list but not edit the segments' do
    before { sign_in create(:user).tap(&:confirm) }

    it 'is forbidden' do
      get "/docs/#{doc.id}/segment_split/edit"

      expect(response).to have_http_status(:forbidden)
    end

    it 'has no link to it from the segment list' do
      get "/docs/#{doc.id}/segments"

      expect(response.body).not_to include('/segment_split/edit')
    end
  end

  it 'forbids a user who cannot access media' do
    sign_in create(:user, root: true).tap(&:confirm)
    allow_any_instance_of(User).to receive(:can_access_media?).and_return(false)

    get "/docs/#{doc.id}/segment_split/edit"

    expect(response).to have_http_status(:forbidden)
  end

  it 'requires signing in' do
    get "/docs/#{doc.id}/segment_split/edit"

    expect(response).to redirect_to('/users/sign_in')
  end
end
