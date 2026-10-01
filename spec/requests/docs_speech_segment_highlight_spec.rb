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
    end

    it 'wraps each speech segment in the rendered body with its playback start time' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).to include('<span class="speech-segment" data-start-ms="0">Hello</span>')
      expect(response.body)
        .to include('<span class="speech-segment" data-start-ms="300">world</span>')
    end

    it 'gives the media player a stable id for JS to hook into' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).to include('id="media-player"')
    end

    it 'renders correctly even when the AudioSegment Denotations are missing or mismatched' do
      # e.g. after a partial deletion via ProjectDoc#delete_annotations, which can delete these
      # like any other Denotation, independently of media_transcript.
      create(:denotation, project: project, doc: doc, hid: 'T1', begin: 0, end: 5, obj: 'AudioSegment')

      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).to include('<span class="speech-segment" data-start-ms="0">Hello</span>')
      expect(response.body)
        .to include('<span class="speech-segment" data-start-ms="300">world</span>')
    end

    it 'wraps speech segments on a span page too, highlighting the span inside them' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}/spans/0-5"

      expect(response.body).to include(
        '<div id="body" class="with_hilight">' \
        '<span class="speech-segment" data-start-ms="0"><span class="highlight">Hello</span></span> ' \
        '<span class="speech-segment" data-start-ms="300">world</span></div>'
      )
    end

    it 'skips speech-segment wrapping when encoding=ascii, since the offsets no longer match set_ascii_body\'s rewritten text' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}", params: { encoding: 'ascii' }

      expect(response.body).not_to include('speech-segment')
      expect(response.body).to include('Hello world')
    end
  end

  context 'when the user cannot access media' do
    let(:doc) { create(:doc, body: 'Hello world', medium: medium) }

    before do
      MediaTranscript.new(
        medium: medium, doc: doc,
        segments: [
          { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
          { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
        ]
      ).save!
    end

    it 'renders the plain body with no speech-segment spans for a user without media access' do
      sign_in create(:user, can_use_media: false).tap(&:confirm)

      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).not_to include('speech-segment')
      expect(response.body).to include('<div id="body">Hello world</div>')
    end

    it 'renders the plain body with no speech-segment spans when not signed in' do
      sign_out user

      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).not_to include('speech-segment')
      expect(response.body).to include('<div id="body">Hello world</div>')
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
