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
    let(:one_segment) { [{ 'text' => 'Hello world', 'start_ms' => 0, 'end_ms' => 1000 }] }

    it 'cannot change the body of a doc transcribed by Whisper' do
      MediaTranscript.create!(medium:, doc:, generation_model: 'whisper:ggml-base.en', segments: one_segment)
      doc.reload.body = 'Changed body'

      expect(doc).not_to be_valid
      expect(doc.errors[:base]).to include('Body cannot be changed for a document transcribed by Whisper')
    end

    it 'can change only the line endings of the body of a doc transcribed by Whisper' do
      MediaTranscript.create!(medium:, doc:, generation_model: 'whisper:ggml-base.en', segments: one_segment)
      doc.update_column(:body, "Hello\r\nworld")
      doc.reload.body = "Hello\nworld"

      expect(doc).to be_valid
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
      expect(media_transcript.segments).to eq([{ 'text' => 'Changed body', 'start_ms' => 0, 'end_ms' => 1000 }])
      expect(media_transcript.text).to eq('Changed body')
    end

    it 'merges the segments of a transcript not from Whisper into one when the body changes' do
      media_transcript = MediaTranscript.create!(medium:, doc:, segments: [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 400 },
        { 'text' => 'world', 'start_ms' => 500, 'end_ms' => 1000 }
      ])

      doc.reload.update!(body: 'Changed body')

      media_transcript.reload
      expect(media_transcript.segments).to eq([{ 'text' => 'Changed body', 'start_ms' => 0, 'end_ms' => 1000 }])
      expect(media_transcript.text).to eq('Changed body')
    end

    it 'leaves the segments alone when only the line endings of the body change' do
      segments = [
        { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 400 },
        { 'text' => 'world', 'start_ms' => 500, 'end_ms' => 1000 }
      ]
      media_transcript = MediaTranscript.create!(medium:, doc:, segments:)
      doc.update_column(:body, "Hello\r\nworld")

      doc.reload.update!(body: "Hello\nworld")

      expect(media_transcript.reload.segments).to eq(segments)
    end

    it 'leaves the segments alone when the body changes to follow the transcript' do
      segments = [
        { 'text' => 'Goodbye', 'start_ms' => 0, 'end_ms' => 400 },
        { 'text' => 'world', 'start_ms' => 500, 'end_ms' => 1000 }
      ]
      media_transcript = MediaTranscript.create!(medium:, doc:, text: 'Goodbye world', segments:)

      doc.reload.update!(body: 'Goodbye world')

      expect(media_transcript.reload.segments).to eq(segments)
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
end
