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
      expect(response.body).to include('id="media-player"', 'id="split-here"', 'id="save-splits"')
      segments = media_transcript.segments.map do |segment|
        { text: segment.text, start_ms: segment.start_ms, end_ms: segment.end_ms,
          line_break_after: segment.line_break_after }
      end
      split_segments = Nokogiri::HTML(response.body).at_css('#split-segments')['data-segments']
      expect(JSON.parse(split_segments, symbolize_names: true)).to eq(segments)
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

    it "saves the segments as split, rebuilding the doc's body, back on the editor" do
      segments = [
        { text: 'Hello', start_ms: 0, end_ms: 300, line_break_after: false },
        { text: 'wo', start_ms: 300, end_ms: 450, line_break_after: false },
        { text: 'rld', start_ms: 450, end_ms: 600, line_break_after: false }
      ]

      patch "/docs/#{doc.id}/segment_split", params: { segment_split: { segments: segments.to_json } }

      expect(response).to redirect_to("/docs/#{doc.id}/segment_split/edit")
      expect(flash[:notice]).to eq('Segments were successfully split.')
      expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello wo rld])
      expect(doc.reload.body).to eq('Hello wo rld')
    end

    it 'saves nothing for invalid segments, telling why back on the editor' do
      segments = [
        { text: 'Hello', start_ms: 0, end_ms: 400, line_break_after: false },
        { text: 'world', start_ms: 300, end_ms: 600, line_break_after: false }
      ]

      patch "/docs/#{doc.id}/segment_split", params: { segment_split: { segments: segments.to_json } }

      expect(response).to redirect_to("/docs/#{doc.id}/segment_split/edit")
      expect(flash[:alert]).to include("must be greater than or equal to the previous segment's end_ms")
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'saves nothing for segments that are not a JSON array of objects, telling why back on the editor' do
      ['{"text": "Hello"}', '["Hello"]'].each do |segments|
        patch "/docs/#{doc.id}/segment_split", params: { segment_split: { segments: } }

        expect(response).to redirect_to("/docs/#{doc.id}/segment_split/edit")
        expect(flash[:alert]).to eq('Segments must be sent as a JSON array of objects.')
      end
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'saves nothing for segments that are not JSON, telling why back on the editor' do
      patch "/docs/#{doc.id}/segment_split", params: { segment_split: { segments: 'not JSON' } }

      expect(response).to redirect_to("/docs/#{doc.id}/segment_split/edit")
      expect(flash[:alert]).to be_present
      expect(doc.reload.body).to eq('Hello world')
    end
  end

  context 'as a user who can access media but cannot update the doc' do
    before { sign_in create(:user).tap(&:confirm) }

    it 'is forbidden' do
      get "/docs/#{doc.id}/segment_split/edit"

      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids saving the segments' do
      segments = [{ text: 'Hello world', start_ms: 0, end_ms: 600, line_break_after: false }]

      patch "/docs/#{doc.id}/segment_split", params: { segment_split: { segments: segments.to_json } }

      expect(response).to have_http_status(:forbidden)
      expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello world])
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
