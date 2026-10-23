# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ManualDocPlaybackService do
  def medium_with_file(media_type, content_type, fixture)
    create(:medium, media_type:, content_type:).tap do |medium|
      medium.file.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', fixture)),
        filename: fixture,
        content_type:
      )
    end
  end

  before do
    allow(AudioAnalyzer).to receive(:new).and_return(instance_double(AudioAnalyzer, duration: 4.98))
    allow(Elasticsearch::IndexQueue).to receive(:index_doc)
  end

  let(:project) { create(:project) }

  def doc_in_project(medium, body)
    create(:doc, body:, medium:).tap { |doc| project.add_doc!(doc) }
  end

  describe '.call' do
    %i[audio video].each do |media_type|
      context "with an #{media_type} medium" do
        let(:medium) do
          media_type == :audio ? medium_with_file(:audio, 'audio/mpeg', 'test_audio.mp3') : medium_with_file(:video, 'video/mp4', 'test_video.mp4')
        end

        it "gives the doc a transcript with the body as one segment spanning the media's duration" do
          doc = doc_in_project(medium, 'Hello world')

          described_class.call(project, doc)

          media_transcript = doc.reload.media_transcript
          expect(media_transcript).to be_persisted
          expect(media_transcript.medium).to eq(medium)
          expect(media_transcript.text).to eq('Hello world')
          expect(media_transcript.segments).to eq([{ 'text' => 'Hello world', 'start_ms' => 0, 'end_ms' => 4_980 }])
        end

        it 'gives the doc, in the project, an AudioSegment block spanning the body' do
          doc = doc_in_project(medium, 'Hello world')

          described_class.call(project, doc)

          expect(doc.blocks.pluck(:project_id, :hid, :begin, :end, :obj))
            .to eq([[project.id, 'B1', 0, 'Hello world'.length, 'AudioSegment']])
          expect(ProjectDoc.find_by(project:, doc:).blocks_num).to eq(1)
          expect(doc.reload.blocks_num).to eq(1)
          expect(project.reload.blocks_num).to eq(1)
        end
      end
    end

    it 'raises for an image medium' do
      doc = doc_in_project(medium_with_file(:image, 'image/png', 'test_image.png'), 'A caption.')

      expect { described_class.call(project, doc) }.to raise_error(ArgumentError, /can't get a transcript/)
    end
  end
end
