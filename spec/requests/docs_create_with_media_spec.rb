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

    it 'adds the doc to the project with an AudioSegment block spanning the body' do
      allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))

      post '/docs.json', params: params.merge(media_params), headers: headers

      expect(response).to have_http_status(:created)
      doc = Doc.last
      expect(doc.blocks.pluck(:project_id, :hid, :begin, :end, :obj))
        .to eq([[project.id, 'B1', 0, 'doctor findings'.length, 'AudioSegment']])
      expect(doc.denotations).to be_empty
      expect(project.reload.blocks_num).to eq(1)
      expect(doc.reload.blocks_num).to eq(1)
    end

    it 'creates none of the doc, transcript or block when saving the block fails' do
      allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))
      allow(Block).to receive(:insert_all).and_raise(ActiveRecord::StatementInvalid, 'insert failed')

      counts = -> { [Doc.count, MediaTranscript.count, Block.count] }

      expect { post '/docs.json', params: params.merge(media_params), headers: headers }.not_to change(&counts)
    end

    it "creates a media_transcript with the body as one segment spanning the media's duration" do
      allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))

      post '/docs.json', params: params.merge(media_params), headers: headers

      expect(response).to have_http_status(:created)
      media_transcript = Doc.last.media_transcript
      expect(media_transcript.medium).to eq(medium)
      expect(media_transcript.text).to eq('doctor findings')
      expect(media_transcript.segments).to match([have_attributes(text: 'doctor findings', start_ms: 0, end_ms: 4_980)])
    end

    it 'creates the body and its segment on one line, with line breaks and runs of spaces as one space' do
      allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))
      params[:doc][:text] = "doctor\r\nfindings  here"

      post '/docs.json', params: params.merge(media_params), headers: headers

      expect(response).to have_http_status(:created)
      doc = Doc.last
      expect(doc.body).to eq('doctor findings here')
      expect(doc.media_transcript.text).to eq('doctor findings here')
      expect(doc.media_transcript.segments.first.text).to eq('doctor findings here')
    end

    it 'plays back the whole body, written with repeated whitespace, as its one segment' do
      allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))

      ["Hello  world", "Hello\n\nworld"].each_with_index do |text, index|
        post '/docs.json', params: params.merge(media_params).deep_merge(doc: { text:, sourceid: "00#{index + 2}" }), headers: headers

        expect(response).to have_http_status(:created)
        doc = Doc.last
        expect(doc.body).to eq('Hello world')
        expect(doc.media_transcript.speech_segment_spans).to eq([{ begin: 0, end: doc.body.length, start_ms: 0 }])
      end
    end

    it "does not create the doc when the media's duration cannot be read" do
      analyzer = instance_double(AudioAnalyzer)
      allow(analyzer).to receive(:duration).and_raise(AudioAnalyzer::DurationDetectionError, 'ffprobe failed')
      allow(AudioAnalyzer).to receive(:new).and_return(analyzer)

      expect {
        post '/docs.json', params: params.merge(media_params), headers: headers
      }.not_to change(Doc, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
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
