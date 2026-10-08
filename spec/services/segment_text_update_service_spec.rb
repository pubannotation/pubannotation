# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SegmentTextUpdateService do
  let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
  let(:doc) { create(:doc, body: 'Hello world', medium:) }
  let!(:media_transcript) { create(:media_transcript, medium:, doc:, text: 'Hello world') }

  describe '.call' do
    it "replaces the segment's text, keeping its timing" do
      described_class.call(media_transcript, 0, 'Goodbye')

      expect(media_transcript.reload.segments).to eq([
        { 'text' => 'Goodbye', 'start_ms' => 0, 'end_ms' => 300 },
        { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
      ])
    end

    it "rebuilds the transcript's text and the doc's body from the segments" do
      described_class.call(media_transcript, 1, 'there')

      expect(media_transcript.reload.text).to eq('Hello there')
      expect(doc.reload.body).to eq('Hello there')
    end

    it 'strips surrounding whitespace from the text' do
      described_class.call(media_transcript, 0, "  Goodbye\n")

      expect(doc.reload.body).to eq('Goodbye world')
    end

    context 'with a non-speech segment' do
      let(:doc) { create(:doc, body: 'Welcome.', medium:) }
      let!(:media_transcript) do
        create(:media_transcript, medium:, doc:, text: 'Welcome.', segments: [
          { 'text' => '(music)', 'start_ms' => 0, 'end_ms' => 3000 },
          { 'text' => 'Welcome.', 'start_ms' => 3000, 'end_ms' => 6000 }
        ])
      end

      it 'adds its text to the body once it is edited into speech' do
        described_class.call(media_transcript, 0, 'Hi.')

        expect(doc.reload.body).to eq('Hi. Welcome.')
      end
    end

    it 'raises for an index with no segment' do
      expect { described_class.call(media_transcript, 2, 'Goodbye') }.to raise_error(ArgumentError, /No segment at index 2/)
    end

    it 'raises for blank text' do
      expect { described_class.call(media_transcript, 0, ' ') }.to raise_error(ArgumentError, /Text is missing/)
    end

    it 'raises for a transcript with no doc' do
      orphan = create(:media_transcript, medium:)

      expect { described_class.call(orphan, 0, 'Goodbye') }.to raise_error(ArgumentError, /has no doc/)
    end

    it "raises, leaving everything unchanged, when the doc's body no longer matches the transcript" do
      doc.update!(body: 'Hello world, edited')

      expect { described_class.call(media_transcript, 0, 'Goodbye') }.to raise_error(ArgumentError, /no longer matches/)
      expect(media_transcript.reload.segments.first['text']).to eq('Hello')
      expect(doc.reload.body).to eq('Hello world, edited')
    end

    it 'rolls back the transcript when the doc fails to save' do
      allow(doc).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      allow(media_transcript).to receive(:doc).and_return(doc)

      expect { described_class.call(media_transcript, 0, 'Goodbye') }.to raise_error(ActiveRecord::RecordInvalid)
      expect(media_transcript.reload.segments.first['text']).to eq('Hello')
      expect(media_transcript.text).to eq('Hello world')
    end
  end
end
