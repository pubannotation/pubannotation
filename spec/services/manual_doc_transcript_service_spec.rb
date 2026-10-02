# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ManualDocTranscriptService do
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
  end

  describe '.applicable?' do
    it 'is true for an audio or video medium with an attached file' do
      expect(described_class.applicable?(medium_with_file(:audio, 'audio/mpeg', 'test_audio.mp3'))).to be(true)
      expect(described_class.applicable?(medium_with_file(:video, 'video/mp4', 'test_video.mp4'))).to be(true)
    end

    it 'is false for an image medium' do
      expect(described_class.applicable?(medium_with_file(:image, 'image/png', 'test_image.png'))).to be(false)
    end

    it 'is false for an audio medium with no attached file' do
      expect(described_class.applicable?(create(:medium, media_type: :audio, content_type: 'audio/mpeg'))).to be(false)
    end

    it 'is false without a medium' do
      expect(described_class.applicable?(nil)).to be_falsey
    end
  end

  describe '.call' do
    %i[audio video].each do |media_type|
      context "with an #{media_type} medium" do
        let(:medium) do
          media_type == :audio ? medium_with_file(:audio, 'audio/mpeg', 'test_audio.mp3') : medium_with_file(:video, 'video/mp4', 'test_video.mp4')
        end

        it "returns an unsaved MediaTranscript with the body as one segment spanning the media's duration" do
          media_transcript = described_class.call(medium, 'Hello world')

          expect(media_transcript).not_to be_persisted
          expect(media_transcript.medium).to eq(medium)
          expect(media_transcript.text).to eq('Hello world')
          expect(media_transcript.segments).to eq([{ 'text' => 'Hello world', 'start_ms' => 0, 'end_ms' => 4_980 }])
        end
      end
    end

    it 'raises for an image medium' do
      medium = medium_with_file(:image, 'image/png', 'test_image.png')

      expect { described_class.call(medium, 'A caption.') }.to raise_error(ArgumentError, /can't get a transcript/)
    end

    it 'raises for an audio medium with no attached file' do
      medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')

      expect { described_class.call(medium, 'Hello world') }.to raise_error(ArgumentError, /can't get a transcript/)
    end
  end
end
