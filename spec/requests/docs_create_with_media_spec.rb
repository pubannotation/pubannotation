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

  context 'with an audio medium' do
    let(:medium) do
      create(:medium, media_type: :audio, content_type: 'audio/mpeg').tap do |medium|
        medium.file.attach(
          io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')),
          filename: 'test_audio.mp3',
          content_type: 'audio/mpeg'
        )
      end
    end
    let(:media_params) { { media: { sourcedb: medium.sourcedb, sourceid: medium.sourceid } } }

    it "creates a media_transcript with the body as one segment spanning the media's duration" do
      allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))

      post '/docs.json', params: params.merge(media_params), headers: headers

      expect(response).to have_http_status(:created)
      media_transcript = Doc.last.media_transcript
      expect(media_transcript.medium).to eq(medium)
      expect(media_transcript.text).to eq('doctor findings')
      expect(media_transcript.segments).to eq([{ 'text' => 'doctor findings', 'start_ms' => 0, 'end_ms' => 4_980 }])
    end

    it "responds with an error, leaving the doc without a media_transcript, when the media's duration cannot be read" do
      analyzer = instance_double(AudioAnalyzer)
      allow(analyzer).to receive(:duration).and_raise(AudioAnalyzer::DurationDetectionError, 'ffprobe failed')
      allow(AudioAnalyzer).to receive(:new).and_return(analyzer)

      expect {
        post '/docs.json', params: params.merge(media_params), headers: headers
      }.to change(Doc, :count).by(1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(Doc.last.media_transcript).to be_nil
    end
  end

  it 'does not create a media_transcript for an audio medium with no attached file' do
    audio_medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')

    post '/docs.json',
         params: params.merge(media: { sourcedb: audio_medium.sourcedb, sourceid: audio_medium.sourceid }),
         headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.media_transcript).to be_nil
  end

  it 'does not create a media_transcript for an image medium' do
    post '/docs.json',
         params: params.merge(media: { sourcedb: medium.sourcedb, sourceid: medium.sourceid }),
         headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.media_transcript).to be_nil
  end

  it 'creates a doc without a medium when media is omitted' do
    post '/docs.json', params: params, headers: headers

    expect(response).to have_http_status(:created)
    expect(Doc.last.medium).to be_nil
  end

  it 'creates a doc without a medium when media is present but left blank (as the form always submits it)' do
    post '/docs.json',
         params: params.merge(media: { sourcedb: '', sourceid: '' }),
         headers: headers

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
