# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaDocCreationService do
  let(:user) { create(:user).tap { |u| u.confirm } }
  let(:project) { create(:project, user: user) }
  let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
  let(:task) { create(:media_transcription_task, medium: medium) }
  let(:media_transcript) do
    create(:media_transcript, medium: medium, media_transcription_task: task, text: 'A generated body.')
  end
  let(:attributes) { { source: nil, sourcedb: 'Example', sourceid: '001' } }

  describe '.call' do
    it "creates a doc from the transcript's text, linked to the medium and the project" do
      doc = described_class.call(project, medium, user, attributes, media_transcript)

      expect(doc).to be_persisted
      expect(doc.body).to eq('A generated body.')
      expect(doc.sourcedb).to eq("Example@#{user.username}")
      expect(doc.sourceid).to eq('001')
      expect(doc.medium).to eq(medium)
      expect(project.docs).to include(doc)
    end

    it 'persists the given source' do
      doc = described_class.call(project, medium, user, attributes.merge(source: 'https://example.com/original'), media_transcript)

      expect(doc.source).to eq('https://example.com/original')
    end

    it 'links the media_transcript to the created doc' do
      doc = described_class.call(project, medium, user, attributes, media_transcript)

      expect(media_transcript.reload.doc).to eq(doc)
    end

    context 'when linking the transcript to the doc fails' do
      it 'raises and rolls back the doc creation, leaving no orphaned doc behind' do
        allow(media_transcript).to receive(:update!).and_raise(StandardError, 'update blew up')

        expect {
          described_class.call(project, medium, user, attributes, media_transcript)
        }.to raise_error(StandardError, 'update blew up')

        expect(Doc.find_by(sourcedb: "Example@#{user.username}", sourceid: '001')).to be_nil
      end
    end

    context 'when adding the doc to the project fails' do
      it 'raises and rolls back the doc creation and transcript link' do
        allow(project).to receive(:add_doc!).and_raise(StandardError, 'add_doc! blew up')

        expect {
          described_class.call(project, medium, user, attributes, media_transcript)
        }.to raise_error(StandardError, 'add_doc! blew up')

        expect(Doc.find_by(sourcedb: "Example@#{user.username}", sourceid: '001')).to be_nil
        expect(media_transcript.reload.doc).to be_nil
      end
    end

    context 'with a transcript containing speech segments' do
      let(:media_transcript) do
        MediaTranscript.new(medium: medium, segments: [
          { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
          { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
        ])
      end

      it 'creates its AudioSegment Denotations' do
        doc = described_class.call(project, medium, user, attributes, media_transcript)

        expect(doc.body).to eq('Hello world')
        denotations = Denotation.where(doc: doc).order(:begin)
        expect(denotations.map { |d| [d.hid, d.begin, d.end, d.obj] }).to eq([
          ['T1', 0, 5, 'AudioSegment'],
          ['T2', 6, 11, 'AudioSegment']
        ])
      end
    end
  end
end
