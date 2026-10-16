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

      it 'checks the Speech column of the speech segments only' do
        media_transcript.update_column(:segments, [{ 'text' => '(music)', 'start_ms' => 0, 'end_ms' => 300 },
                                                   { 'text' => 'Hello world', 'start_ms' => 300, 'end_ms' => 600 }])

        get "/docs/#{doc.id}/segments"

        expect(response.body.scan('<td class="speech">✓</td>').size).to eq(1)
        expect(response.body.scan('<td class="speech"></td>').size).to eq(1)
      end

      it 'gives each segment an Edit button for the dialog' do
        get "/docs/#{doc.id}/segments"

        expect(response.body).to include(%(data-url="/docs/#{doc.id}/segments/1"), 'data-text="world"')
        expect(response.body).to include('<dialog id="segment-dialog" aria-labelledby="segment-dialog-title" data-open-on-load="false">')
      end

      it "names the dialog by its heading and labels the dialog's textarea" do
        get "/docs/#{doc.id}/segments"

        expect(response.body).to include('<h2 id="segment-dialog-title">Edit segment text</h2>')
        expect(response.body).to include('<label for="segment_text">Text</label>', 'id="segment_text"')
      end
    end

    describe 'PATCH /docs/:doc_id/segments/:index' do
      it "updates the segment's text and the doc's body, then goes back to the list" do
        patch "/docs/#{doc.id}/segments/1", params: { segment: { text: 'there' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(media_transcript.reload.segments.last['text']).to eq('there')
        expect(doc.reload.body).to eq('Hello there')
      end

      it 'keeps an edit of another segment saved since the page was loaded' do
        allow_any_instance_of(MediaTranscript).to receive(:with_lock).and_wrap_original do |original, *args, &block|
          # Another request saves its edit of segment 0 just before this one locks the transcript.
          MediaTranscript.find(media_transcript.id).tap { _1.set_segment_text(0, 'Goodbye') }.save!
          original.call(*args, &block)
        end

        patch "/docs/#{doc.id}/segments/1", params: { segment: { text: 'there' } }

        expect(media_transcript.reload.segments.map { _1['text'] }).to eq(%w[Goodbye there])
        expect(doc.reload.body).to eq('Goodbye there')
      end

      it 'saves line breaks submitted as CRLF as LF' do
        patch "/docs/#{doc.id}/segments/1", params: { segment: { text: "there\r\nagain" } }

        expect(media_transcript.reload.segments.last['text']).to eq("there\nagain")
        expect(doc.reload.body).to eq("Hello there\nagain")
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

    it 'responds with not found for a doc that does not exist' do
      get '/docs/0/segments'

      expect(response).to have_http_status(:not_found)
    end

    it 'responds with not found for a doc with an image' do
      image_doc = create(:doc, medium: create(:medium, media_type: :image, content_type: 'image/png'))

      get "/docs/#{image_doc.id}/segments"

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'as a user who can access media but cannot update the doc' do
    before { sign_in create(:user).tap(&:confirm) }

    it 'lists the segments all the same, with no Edit buttons or dialog' do
      get "/docs/#{doc.id}/segments"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hello', 'world')
      expect(response.body).not_to include('edit-segment', 'segment-dialog')
    end

    it 'forbids the update' do
      patch "/docs/#{doc.id}/segments/1", params: { segment: { text: 'there' } }

      expect(response).to have_http_status(:forbidden)
      expect(doc.reload.body).to eq('Hello world')
    end

    it 'links to the segment list on the doc detail page' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).to include("href=\"/docs/#{doc.id}/segments\"")
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

    it 'has no link on the doc detail page' do
      get "/docs/sourcedb/#{doc.sourcedb}/sourceid/#{doc.sourceid}"

      expect(response.body).not_to include("/docs/#{doc.id}/segments")
    end
  end

  it 'requires signing in' do
    get "/docs/#{doc.id}/segments"

    expect(response).to redirect_to('/users/sign_in')
  end
end
