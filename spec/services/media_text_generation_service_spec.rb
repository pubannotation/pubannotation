# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaTextGenerationService do
  let(:image_medium) do
    medium = create(:medium)
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.png')),
      filename: 'test_image.png',
      content_type: 'image/png'
    )
    medium
  end
  let(:audio_medium) do
    medium = create(:medium, media_type: :audio, content_type: 'audio/mpeg')
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3')),
      filename: 'test_audio.mp3',
      content_type: 'audio/mpeg'
    )
    medium
  end
  let(:video_medium) do
    medium = create(:medium, media_type: :video, content_type: 'video/mp4')
    medium.file.attach(
      io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_video.mp4')),
      filename: 'test_video.mp4',
      content_type: 'video/mp4'
    )
    medium
  end

  describe '#call' do
    context 'with a valid image medium' do
      before do
        allow(ImageCaptionService).to receive(:new).and_return(instance_double(ImageCaptionService, call: 'A generated caption.'))
      end

      it 'returns the generated caption' do
        result = described_class.new(image_medium).call

        expect(result).to eq('A generated caption.')
      end

      it 'passes a given caption_model through to ImageCaptionService' do
        described_class.new(image_medium, caption_model: 'medgemma:4b').call

        expect(ImageCaptionService).to have_received(:new).with(anything, model: 'medgemma:4b')
      end
    end

    context 'with a valid audio medium' do
      before do
        allow(AudioTranscriptionService).to receive(:new).and_return(
          instance_double(AudioTranscriptionService, call: [
            { 'text' => 'A generated', 'start_ms' => 0, 'end_ms' => 500 },
            { 'text' => 'transcript.', 'start_ms' => 500, 'end_ms' => 1000 }
          ])
        )
      end

      it 'returns the transcript joined from the segments' do
        result = described_class.new(audio_medium).call

        expect(result).to eq('A generated transcript.')
      end
    end

    context 'with a valid video medium' do
      before do
        allow(VideoTranscriptionService).to receive(:new).and_return(
          instance_double(VideoTranscriptionService, call: [
            { 'text' => 'A generated', 'start_ms' => 0, 'end_ms' => 500 },
            { 'text' => 'transcript.', 'start_ms' => 500, 'end_ms' => 1000 }
          ])
        )
      end

      it 'returns the transcript joined from the segments' do
        result = described_class.new(video_medium).call

        expect(result).to eq('A generated transcript.')
      end
    end

    context 'when the medium has an unsupported media type' do
      it 'raises' do
        medium = image_medium
        allow(medium).to receive_messages(image?: false, audio?: false, video?: false, media_type: nil)

        expect {
          described_class.new(medium).call
        }.to raise_error(ArgumentError, /Unsupported media type/)
      end
    end

    context 'when the medium has no attached file' do
      let(:medium_without_file) { create(:medium) }

      it 'raises' do
        expect {
          described_class.new(medium_without_file).call
        }.to raise_error(ArgumentError, /no attached file/)
      end
    end
  end
end
