# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioSegmentDenotationService do
  let(:project) { create(:project) }
  let(:medium) { create(:medium, media_type: :audio, content_type: 'audio/mpeg') }
  let(:doc) { create(:doc, body: 'Hello world', medium:).tap { |doc| project.add_doc!(doc) } }
  let(:media_transcript) do
    MediaTranscript.new(medium:, segments: [
      { 'text' => 'Hello', 'start_ms' => 0, 'end_ms' => 300 },
      { 'text' => 'world', 'start_ms' => 300, 'end_ms' => 600 }
    ])
  end

  describe '.call' do
    it 'creates one Denotation per speech segment, spanning its offset into the doc body' do
      described_class.call(project, doc, media_transcript)

      denotations = Denotation.where(doc:).order(:begin)
      expect(denotations.map { |d| [d.project_id, d.hid, d.begin, d.end, d.obj] }).to eq([
        [project.id, 'T1', 0, 5, 'AudioSegment'],
        [project.id, 'T2', 6, 11, 'AudioSegment']
      ])
    end

    it 'increments denotations_num on the project_doc, doc, and project by the segment count once' do
      described_class.call(project, doc, media_transcript)

      expect(ProjectDoc.find_by(project:, doc:).denotations_num).to eq(2)
      expect(doc.reload.denotations_num).to eq(2)
      expect(project.reload.denotations_num).to eq(2)
    end

    it "touches the project's updated_at" do
      doc
      project.update_column(:updated_at, 1.year.ago)

      expect { described_class.call(project, doc, media_transcript) }.to(change { project.reload.updated_at })
    end

    it 'issues a single INSERT for all the segment denotations' do
      doc
      insert_queries = []
      callback = lambda do |*, payload|
        insert_queries << payload[:sql] if payload[:sql]&.match?(/\AINSERT INTO "denotations"/)
      end

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        described_class.call(project, doc, media_transcript)
      end

      expect(insert_queries.size).to eq(1)
    end

    context 'when segments mix speech and non-speech labels' do
      let(:doc) { create(:doc, body: 'Welcome.', medium:).tap { |doc| project.add_doc!(doc) } }
      let(:media_transcript) do
        MediaTranscript.new(medium:, segments: [
          { 'text' => '(music)', 'start_ms' => 0, 'end_ms' => 3000 },
          { 'text' => 'Welcome.', 'start_ms' => 3000, 'end_ms' => 6000 }
        ])
      end

      it 'creates a Denotation for the speech segment only' do
        described_class.call(project, doc, media_transcript)

        expect(Denotation.where(doc:).pluck(:begin, :end, :obj)).to eq([[0, 8, 'AudioSegment']])
      end
    end

    context 'with a transcript that has no speech segments (e.g. an image caption)' do
      let(:media_transcript) { MediaTranscript.new(medium:, text: 'A generated caption.') }

      it 'creates no Denotations and leaves the counters alone' do
        described_class.call(project, doc, media_transcript)

        expect(Denotation.where(doc:)).to be_empty
        expect(project.reload.denotations_num).to eq(0)
      end
    end
  end
end
