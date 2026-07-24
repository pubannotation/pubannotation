# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioSilenceDetector do
  let(:audio_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3').to_s }

  describe '#silent?' do
    def stub_ffmpeg_stderr(stderr)
      allow(Open3).to receive(:capture3)
        .with('ffmpeg', '-i', audio_path, '-af', 'volumedetect', '-f', 'null', '-')
        .and_return(['', stderr, instance_double(Process::Status)])
    end

    it 'returns true when max_volume is below the threshold' do
      stub_ffmpeg_stderr('[Parsed_volumedetect_0] max_volume: -91.0 dB')
      expect(described_class.new(audio_path).silent?).to be true
    end

    it 'returns false when max_volume is above the threshold' do
      stub_ffmpeg_stderr('[Parsed_volumedetect_0] max_volume: -2.1 dB')
      expect(described_class.new(audio_path).silent?).to be false
    end

    it 'returns false when max_volume cannot be parsed from ffmpeg output' do
      stub_ffmpeg_stderr('some unrelated ffmpeg error output')
      expect(described_class.new(audio_path).silent?).to be false
    end
  end
end
