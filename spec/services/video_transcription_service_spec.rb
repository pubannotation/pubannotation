# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VideoTranscriptionService do
  let(:video_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_video.mp4').to_s }

  describe '#call' do
    context 'when ffmpeg succeeds' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3) do |*args|
          expect(args[0..1]).to eq(['ffmpeg', '-y'])
          expect(args[2..3]).to eq(['-i', video_path])
          expect(args[4..5]).to eq(['-vn', '-f'])
          expect(args[6]).to eq('wav')
          expect(args[7]).to end_with('.wav')
          ['', '', success_status]
        end
        allow(AudioTranscriptionService).to receive(:new) do |audio_path|
          expect(audio_path).to end_with('.wav')
          instance_double(AudioTranscriptionService, call: 'A generated transcript.')
        end
      end

      it 'transcribes the audio extracted from the video' do
        result = described_class.new(video_path).call
        expect(result).to eq('A generated transcript.')
      end
    end

    context 'when ffmpeg fails' do
      before do
        failure_status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(['', 'error: invalid data found', failure_status])
      end

      it 'raises without invoking AudioTranscriptionService' do
        expect(AudioTranscriptionService).not_to receive(:new)
        expect {
          described_class.new(video_path).call
        }.to raise_error(/Audio extraction failed.*invalid data found/)
      end
    end
  end
end
