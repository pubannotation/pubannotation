# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'GET /docs/:sourcedb/:sourceid speech segment highlighting', type: :request do
  include Devise::Test::IntegrationHelpers

  before do
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
    allow(Elasticsearch::IndexQueue).to receive(:delete_doc)
  end

  let(:user) { create(:user).tap(&:confirm) }
  let(:project) { create(:project, user: user) }
  let(:medium) do
    medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')),
      filename: 'test_audio.mp3',
      content_type: 'audio/mpeg'
    )
    medium
  end
  before { sign_in user }

  context 'when the doc has a media_transcript with speech segments' do
    let(:doc) { create(:doc, body: 'Hello world', medium: medium) }

    before do
      MediaTranscript.new(
        medium: medium, doc: doc,
        segments: [
          { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
          { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
        ]
      ).save!

      create(:denotation, project: project, doc: doc, hid: 'T1', begin: 0, end: 5, obj: 'AudioSegment')
      create(:denotation, project: project, doc: doc, hid: 'T2', begin: 6, end: 11, obj: 'AudioSegment')
    end

    it 'wraps each speech segment in the rendered body with its playback time range' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).to include('<span class="speech-segment" data-start-ms="0" data-end-ms="300">Hello</span>')
      expect(response.body)
        .to include('<span class="speech-segment" data-start-ms="300" data-end-ms="600">world</span>')
    end

    it 'gives the media player a stable id for JS to hook into' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).to include('id="media-player"')
    end
  end

  context 'when the doc has no media_transcript' do
    let(:doc) { create(:doc, body: 'Plain text with no media.') }

    it 'renders the plain body with no speech-segment spans' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).not_to include('speech-segment')
      expect(response.body).to include('Plain text with no media.')
    end
  end
end
