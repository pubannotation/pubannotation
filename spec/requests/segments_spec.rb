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
  let(:hello) { media_transcript.segments.first }
  let(:world) { media_transcript.segments.last }

  context 'as a root user' do
    before { sign_in root_user }

    describe 'GET /docs/:doc_id/segments' do
      it 'lists the segments with their times' do
        get "/docs/#{doc.id}/segments"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('0:00.300', 'Hello', 'world')
        expect(response.body).to include('<td class="segment-text" title="Hello" tabindex="0">Hello</td>')
      end

      it 'checks the Speech column of the speech segments only' do
        media_transcript.segments.first.update_column(:text, '(music)')

        get "/docs/#{doc.id}/segments"

        expect(response.body.scan('<td class="speech">✓</td>').size).to eq(1)
        expect(response.body.scan('<td class="speech"></td>').size).to eq(1)
      end

      it 'gives each segment an Edit button for the dialog' do
        get "/docs/#{doc.id}/segments"

        expect(response.body).to include(%(data-url="/docs/#{doc.id}/segments/#{world.id}"), 'data-index="1"', 'data-text="world"')
        dialog = Nokogiri::HTML(response.body).at_css('dialog#segment-dialog')
        expect(dialog.attributes.transform_values(&:value)).to include('aria-labelledby' => 'segment-dialog-title',
                                                                       'data-open-on-load' => 'false')
      end

      it "names the dialog by its heading and labels the dialog's text field" do
        get "/docs/#{doc.id}/segments"

        expect(response.body).to include('<h2 id="segment-dialog-title">Edit segment text</h2>')
        expect(response.body).to include('<label for="segment_text">Text</label>', 'id="segment_text"')
      end
    end

    describe 'the Line break column' do
      it 'gives each speech segment but the last a checkbox, saved as it changes' do
        get "/docs/#{doc.id}/segments"

        expect(response.body).to include('<th>Line break</th>', 'id="segment_line_break_after_0"')
        expect(response.body).not_to include('id="segment_line_break_after_1"')
        expect(response.body).to include(%(class="line-break-form" action="/docs/#{doc.id}/segments/#{hello.id}"))
      end
    end

    describe 'PATCH /docs/:doc_id/segments/:id with a line break' do
      it "puts a line break after the segment into the doc's body, then goes back to the list" do
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { line_break_after: '1' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(media_transcript.reload.segments.first.line_break_after).to be(true)
        expect(media_transcript.text).to eq("Hello\nworld")
        expect(doc.reload.body).to eq("Hello\nworld")
      end

      it 'goes back to the list with the error, not opening the dialog, when the line break is not saved' do
        allow_any_instance_of(MediaTranscript).to receive(:update_segment!).and_raise(ArgumentError, 'Line break failed.')

        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { line_break_after: '1' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        follow_redirect!
        expect(response.body).to include('Line break failed.', 'data-open-on-load="false"')
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'goes back to the list with the error for a segment no line break can follow, e.g. the last one' do
        patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { line_break_after: '1' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(flash[:alert]).to eq('No line break can follow this segment.')
        expect(media_transcript.reload.segments.last.line_break_after).to be(false)
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'goes back to the list with the error for a null line break, leaving the body as it was' do
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { line_break_after: nil } }, as: :json

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(flash[:alert]).to include('line break after is not included in the list')
        expect(media_transcript.reload.segments.first.line_break_after).to be(false)
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'puts a space back when the checkbox is unchecked' do
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { line_break_after: '1' } }
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { line_break_after: '0' } }

        expect(media_transcript.reload.segments.first.line_break_after).to be(false)
        expect(doc.reload.body).to eq('Hello world')
      end
    end

    describe 'GET /docs/:doc_id/segments with denotations' do
      it 'gives each Edit button the pieces of its segment' do
        project = create(:project)
        create(:denotation, project:, doc:, begin: 0, end: 5, obj: 'Protein')

        get "/docs/#{doc.id}/segments"

        pieces = Nokogiri::HTML(response.body).css('button.edit-segment').map { JSON.parse(it['data-pieces']) }
        expect(pieces).to eq([[{ 'begin' => 0, 'end' => 5, 'text' => 'Hello', 'labels' => ["#{project.name}: Protein"] }], []])
      end

      it 'queries the denotations once for all the segments' do
        project = create(:project)
        create(:denotation, project:, doc:, begin: 0, end: 5)
        create(:denotation, project:, doc:, begin: 6, end: 11)
        queries = []
        callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?('FROM "denotations"') }

        ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') { get "/docs/#{doc.id}/segments" }

        expect(queries.size).to eq(1)
      end

      it 'no longer says the annotations after an edited segment are not moved' do
        get "/docs/#{doc.id}/segments"

        expect(response.body).not_to include('The annotations after it are not moved.')
      end
    end

    describe 'PATCH /docs/:doc_id/segments/:id with a piece' do
      let!(:denotation) { create(:denotation, project: create(:project), doc:, begin: 0, end: 5) }

      it 'replaces the piece and shifts the denotations, then goes back to the list' do
        patch "/docs/#{doc.id}/segments/#{hello.id}",
              params: { segment: { piece_begin: 0, piece_end: 5, piece_text: 'Hello', text: 'Goodbye' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(doc.reload.body).to eq('Goodbye world')
        expect(denotation.reload.attributes.values_at('begin', 'end')).to eq([0, 7])
      end

      it 'reopens the dialog with the error for a stale piece' do
        patch "/docs/#{doc.id}/segments/#{hello.id}",
              params: { segment: { piece_begin: 0, piece_end: 5, piece_text: 'Hallo', text: 'Goodbye' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('The segment has changed since the page was loaded.', 'data-open-on-load="true"')
        expect(doc.reload.body).to eq('Hello world')
      end

      it 'reopens the dialog with the pieces of the segment as another request has just changed it' do
        allow_any_instance_of(MediaTranscript).to receive(:with_lock).and_wrap_original do |original, *args, &block|
          # Another request lengthens the segment, splitting the piece, just before this one locks the transcript.
          MediaTranscript.find(media_transcript.id).tap { _1.set_segment_text(hello, 'Hello there') }.save!
          create(:denotation, project: denotation.project, doc:, begin: 2, end: 5)
          create(:denotation, project: denotation.project, doc:, begin: 6, end: 11)
          original.call(*args, &block)
        end

        patch "/docs/#{doc.id}/segments/#{hello.id}",
              params: { segment: { piece_begin: 0, piece_end: 5, piece_text: 'Hello', text: 'Goodbye' } }

        expect(response).to have_http_status(:unprocessable_content)
        dialog = Nokogiri::HTML(response.body).at_css('#segment-dialog')
        expect(JSON.parse(dialog['data-pieces']).map { it['text'] }).to eq(%w[He llo there])
      end

      it 'refuses the whole text of a segment with denotations' do
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { text: 'Hi' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Edit a segment with denotations piece by piece.')
        expect(doc.reload.body).to eq('Hello world')
      end
    end

    describe 'marking a segment as no speech' do
      it 'gives the dialog a No speech button carrying the label to save' do
        get "/docs/#{doc.id}/segments"

        expect(response.body).to include('id="segment-dialog-no-speech"', 'data-text="(no speech)"')
      end

      it 'takes the segment out of the text' do
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { text: NonSpeechTextMatcher::NO_SPEECH } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(media_transcript.reload.segments.first.text).to eq('(no speech)')
        expect(doc.reload.body).to eq('world')
      end

      it 'refuses to mark the last speech segment, showing why in the dialog' do
        patch "/docs/#{doc.id}/segments/#{hello.id}", params: { segment: { text: NonSpeechTextMatcher::NO_SPEECH } }
        patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { text: NonSpeechTextMatcher::NO_SPEECH } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Segments must have speech', 'data-open-on-load="true"')
        expect(doc.reload.body).to eq('world')
      end
    end

    describe 'PATCH /docs/:doc_id/segments/:id' do
      it "updates the segment's text and the doc's body, then goes back to the list" do
        patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { text: 'there' } }

        expect(response).to redirect_to("/docs/#{doc.id}/segments")
        expect(media_transcript.reload.segments.last.text).to eq('there')
        expect(doc.reload.body).to eq('Hello there')
      end

      it 'keeps an edit of another segment saved since the page was loaded' do
        allow_any_instance_of(MediaTranscript).to receive(:with_lock).and_wrap_original do |original, *args, &block|
          # Another request saves its edit of the first segment just before this one locks the transcript.
          MediaTranscript.find(media_transcript.id).tap { _1.set_segment_text(hello, 'Goodbye') }.save!
          original.call(*args, &block)
        end

        patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { text: 'there' } }

        expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Goodbye there])
        expect(doc.reload.body).to eq('Goodbye there')
      end

      it 'saves line breaks as spaces, keeping the segment on one line' do
        patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { text: "there\r\nagain" } }

        expect(media_transcript.reload.segments.last.text).to eq('there again')
        expect(doc.reload.body).to eq('Hello there again')
      end

      it 'shows the error, reopening the dialog with the entered text, when the update is rejected' do
        patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { text: ' ' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Text is missing.', 'data-open-on-load="true"', '<span id="segment-dialog-index">#1</span>', 'value=" "')
        expect(response.body).to include(%(action="/docs/#{doc.id}/segments/#{world.id}"))
        expect(media_transcript.reload.segments.last.text).to eq('world')
      end

      it 'responds with not found for an id with no segment' do
        patch "/docs/#{doc.id}/segments/0", params: { segment: { text: 'there' } }

        expect(response).to have_http_status(:not_found)
      end

      it "responds with not found for another doc's segment" do
        other_doc = create(:doc, body: 'Hello world', medium: create(:medium, media_type: :audio, content_type: 'audio/mpeg'))
        other_segment = create(:media_transcript, medium: other_doc.medium, doc: other_doc, text: 'Hello world').segments.first

        patch "/docs/#{doc.id}/segments/#{other_segment.id}", params: { segment: { text: 'there' } }

        expect(response).to have_http_status(:not_found)
        expect(other_segment.reload.text).to eq('Hello')
      end

      it 'responds with not found for a segment replaced since the page was loaded, e.g. by a split' do
        replaced_id = world.id
        media_transcript.replace_segments([
          build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
          build(:segment, :without_transcript, sort_order: 1, text: 'wor', start_ms: 300, end_ms: 450),
          build(:segment, :without_transcript, sort_order: 2, text: 'ld', start_ms: 450, end_ms: 600)
        ])
        media_transcript.save!

        patch "/docs/#{doc.id}/segments/#{replaced_id}", params: { segment: { text: 'there' } }

        expect(response).to have_http_status(:not_found)
        expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello wor ld])
      end

      it 'responds with not found for a segment replaced just before the transcript is locked' do
        replaced_id = world.id
        allow_any_instance_of(MediaTranscript).to receive(:with_lock).and_wrap_original do |original, *args, &block|
          # Another request's split, landing after set_segment found the segment.
          other = MediaTranscript.find(media_transcript.id)
          other.replace_segments([
            build(:segment, :without_transcript, sort_order: 0, text: 'Hello', start_ms: 0, end_ms: 300),
            build(:segment, :without_transcript, sort_order: 1, text: 'wor', start_ms: 300, end_ms: 450),
            build(:segment, :without_transcript, sort_order: 2, text: 'ld', start_ms: 450, end_ms: 600)
          ])
          other.save!
          original.call(*args, &block)
        end

        patch "/docs/#{doc.id}/segments/#{replaced_id}", params: { segment: { text: 'there' } }

        expect(response).to have_http_status(:not_found)
        expect(media_transcript.reload.segments.map(&:text)).to eq(%w[Hello wor ld])
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
      expect(response.body).not_to include('edit-segment', 'segment-dialog', 'Line break', 'line-break-form')
    end

    it 'forbids the update' do
      patch "/docs/#{doc.id}/segments/#{world.id}", params: { segment: { text: 'there' } }

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
