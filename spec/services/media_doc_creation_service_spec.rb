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
  end
end
