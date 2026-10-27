# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Doc, type: :model do
  subject(:doc) { create(:doc, medium: medium) }

  context 'with medium' do
    let(:medium) { create(:medium) }

    describe 'medium association' do
      it { is_expected.to have_attributes(medium: medium) }
    end

    describe 'medium_id immutability' do
      it 'cannot change medium after creation' do
        other_medium = create(:medium, sourcedb: 'DB2', sourceid: 'id2')
        doc.medium = other_medium

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end

  context 'without medium' do
    let(:medium) { nil }

    describe 'medium association' do
      it { is_expected.to have_attributes(medium: nil) }
    end

    describe 'medium_id immutability' do
      it 'cannot add medium after creation' do
        new_medium = create(:medium)
        doc.medium = new_medium

        expect(doc).not_to be_valid
        expect(doc.errors[:base]).to include('Media reference cannot be changed after creation')
      end
    end
  end

  describe 'body immutability with a media transcript' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }
    # A new Segment each time, as one can belong to only one transcript.
    def one_segment = [Segment.new(sort_order: 0, text: 'Hello world', start_ms: 0, end_ms: 1000)]

    it 'cannot change the body of a doc transcribed by Whisper' do
      MediaTranscript.create!(medium:, doc:, generation_model: 'whisper:ggml-base.en', segments: one_segment)
      doc.reload.body = 'Changed body'

      expect(doc).not_to be_valid
      expect(doc.errors[:base]).to include('Body cannot be changed directly for a document transcribed by Whisper; edit its segments instead')
    end

    it 'can change the body of a doc transcribed by Whisper to follow its transcript' do
      media_transcript = MediaTranscript.create!(medium:, doc:, generation_model: 'whisper:ggml-base.en', segments: one_segment)
      media_transcript.update_column(:text, 'Goodbye world')
      doc.reload.body = 'Goodbye world'

      expect(doc).to be_valid
    end

    it 'can still change other attributes of a doc transcribed by Whisper' do
      MediaTranscript.create!(medium:, doc:, generation_model: 'whisper:ggml-base.en', segments: one_segment)
      doc.reload.source = 'https://example.com/changed'

      expect(doc).to be_valid
    end

    it 'carries a body change over to a single-segment transcript not from Whisper' do
      media_transcript = MediaTranscript.create!(medium:, doc:, segments: one_segment)

      doc.reload.update!(body: 'Changed body')

      media_transcript.reload
      expect(media_transcript.segment_values).to eq([{ 'text' => 'Changed body', 'start_ms' => 0, 'end_ms' => 1000 }])
      expect(media_transcript.text).to eq('Changed body')
    end

    it 'merges the segments of a transcript not from Whisper into one when the body changes' do
      media_transcript = MediaTranscript.create!(medium:, doc:, segment_values: [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 400 },
        { 'text' => 'world', 'start_ms' => 500, 'end_ms' => 1000 }
      ])

      doc.reload.update!(body: 'Changed body')

      media_transcript.reload
      expect(media_transcript.segment_values).to eq([{ 'text' => 'Changed body', 'start_ms' => 0, 'end_ms' => 1000 }])
      expect(media_transcript.text).to eq('Changed body')
    end

    it 'puts a body stored with CRLF, and its transcript, on one line as it gets saved again' do
      media_transcript = MediaTranscript.create!(medium:, doc:, text: "Hello\r\nworld",
                                                 segment_values: [{ 'text' => "Hello\r\nworld", 'start_ms' => 0, 'end_ms' => 1000 }])
      # Stored with CRLF as before the body was normalized; SQL, since update_column normalizes it too.
      Doc.where(id: doc.id).update_all(['body = ?', "Hello\r\nworld"])

      doc.reload.update!(body: "Hello\r\nworld")

      media_transcript.reload
      expect(doc.reload.body).to eq('Hello world')
      expect(media_transcript.text).to eq('Hello world')
      expect(media_transcript.segment_values).to eq([{ 'text' => 'Hello world', 'start_ms' => 0, 'end_ms' => 1000 }])
    end

    it 'cannot change the body of a doc with audio or video to only a non-speech label' do
      MediaTranscript.create!(medium:, doc:, segments: one_segment)
      doc.reload.body = '(music)'

      expect(doc).not_to be_valid
      expect(doc.errors[:body]).to include('must have speech for a document with audio or video')
    end

    it 'leaves the segments alone when the body changes to follow the transcript' do
      segments = [
        { 'text' => 'Goodbye', 'start_ms' => 0, 'end_ms' => 400 },
        { 'text' => 'world', 'start_ms' => 500, 'end_ms' => 1000 }
      ]
      media_transcript = MediaTranscript.create!(medium:, doc:, text: 'Goodbye world', segment_values: segments)

      doc.reload.update!(body: 'Goodbye world')

      expect(media_transcript.reload.segment_values).to eq(segments)
    end

    it 'can change the body of a doc with an image transcript, carrying it over to the caption' do
      image = create(:medium, media_type: :image, content_type: 'image/png')
      image_doc = create(:doc, body: 'A caption.', medium: image)
      media_transcript = MediaTranscript.create!(medium: image, doc: image_doc, text: 'A caption.', generation_model: 'moondream')

      image_doc.reload.update!(body: 'Changed body')

      expect(media_transcript.reload.text).to eq('Changed body')
    end

    it 'can change the body of a doc with no media transcript' do
      doc.body = 'Changed body'

      expect(doc).to be_valid
    end
  end
  describe '#segment_editable_by?' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }

    before { create(:media_transcript, medium:, doc:, text: 'Hello world') }

    it 'is true for a user who can update the doc, with segments' do
      expect(doc.reload.segment_editable_by?(create(:user, root: true))).to be(true)
    end

    it 'is false for a user who cannot update the doc' do
      expect(doc.reload.segment_editable_by?(create(:user))).to be(false)
    end

    it 'is false with no segments, e.g. an image caption' do
      image = create(:medium, media_type: :image, content_type: 'image/png')
      image_doc = create(:doc, body: 'A caption.', medium: image)
      create(:media_transcript, medium: image, doc: image_doc, text: 'A caption.', segments: [])

      expect(image_doc.reload.segment_editable_by?(create(:user, root: true))).to be(false)
    end
  end

  describe '#segment_listable_by?' do
    let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
    let(:doc) { create(:doc, body: 'Hello world', medium:) }

    it 'is true with segments, even for a user who cannot update the doc' do
      create(:media_transcript, medium:, doc:, text: 'Hello world')

      expect(doc.reload.segment_listable_by?(create(:user))).to be(true)
    end

    it 'is false with no segments, e.g. an image caption' do
      image = create(:medium, media_type: :image, content_type: 'image/png')
      image_doc = create(:doc, body: 'A caption.', medium: image)
      create(:media_transcript, medium: image, doc: image_doc, text: 'A caption.', segments: [])

      expect(image_doc.reload.segment_listable_by?(create(:user))).to be(false)
    end

    it 'is false with no media transcript' do
      expect(doc.segment_listable_by?(create(:user))).to be_falsey
    end
  end
end
