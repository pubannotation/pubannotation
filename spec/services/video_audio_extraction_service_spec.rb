# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VideoAudioExtractionService do
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
      end

      it 'yields the path to the extracted audio file' do
        extracted_path = nil
        described_class.new(video_path).call { |path| extracted_path = path }

        expect(extracted_path).to end_with('.wav')
      end
    end

    context 'when ffmpeg fails' do
      before do
        failure_status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).and_return(['', 'error: invalid data found', failure_status])
      end

      it 'raises without yielding' do
        expect {
          described_class.new(video_path).call { |path| path }
        }.to raise_error(/Audio extraction failed.*invalid data found/)
      end
    end
  end
end
