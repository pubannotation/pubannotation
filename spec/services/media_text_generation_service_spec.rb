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

      it 'returns an unsaved MediaTranscript with the caption as its text and no segments' do
        media_transcript = described_class.new(image_medium).call

        expect(media_transcript).not_to be_persisted
        expect(media_transcript.medium).to eq(image_medium)
        expect(media_transcript.text).to eq('A generated caption.')
        expect(media_transcript.segments).to eq([])
      end
    end

    context 'with a valid audio medium' do
      let(:segments) { [{ 'text' => 'A generated transcript.', 'start_ms' => 0, 'end_ms' => 1200 }] }

      before do
        allow(AudioTranscriptionService).to receive(:new).and_return(
          instance_double(AudioTranscriptionService, call: segments)
        )
      end

      it 'returns an unsaved MediaTranscript with the speech text and the raw segments' do
        media_transcript = described_class.new(audio_medium).call

        expect(media_transcript).not_to be_persisted
        expect(media_transcript.medium).to eq(audio_medium)
        expect(media_transcript.text).to eq('A generated transcript.')
        expect(media_transcript.segments).to eq(segments)
      end

      context 'when segments mix speech and non-speech labels' do
        let(:segments) do
          [
            { 'text' => '(music)', 'start_ms' => 0, 'end_ms' => 3000 },
            { 'text' => 'Welcome to the conference.', 'start_ms' => 3000, 'end_ms' => 6000 }
          ]
        end

        it 'sets text from speech segments only, while keeping all segments' do
          media_transcript = described_class.new(audio_medium).call

          expect(media_transcript.text).to eq('Welcome to the conference.')
          expect(media_transcript.segments).to eq(segments)
        end
      end
    end

    context 'with a valid video medium' do
      let(:segments) { [{ 'text' => 'A generated transcript.', 'start_ms' => 0, 'end_ms' => 1200 }] }

      before do
        allow(VideoTranscriptionService).to receive(:new).and_return(
          instance_double(VideoTranscriptionService, call: segments)
        )
      end

      it 'returns an unsaved MediaTranscript with the speech text and the raw segments' do
        media_transcript = described_class.new(video_medium).call

        expect(media_transcript).not_to be_persisted
        expect(media_transcript.medium).to eq(video_medium)
        expect(media_transcript.text).to eq('A generated transcript.')
        expect(media_transcript.segments).to eq(segments)
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
