# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioAnalyzer do
  let(:audio_path) { '/tmp/audio.wav' }
  let(:analyzer) { described_class.new(audio_path) }
  let(:status) { instance_double(Process::Status, success?: true) }
  let(:probe_args) do
    ['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
     '-of', 'default=noprint_wrappers=1:nokey=1', audio_path]
  end
  let(:volume_args) { ['ffmpeg', '-i', audio_path, '-af', 'volumedetect', '-f', 'null', '-'] }

  it 'returns duration in seconds and maximum volume in dB' do
    expect(Open3).to receive(:capture3).with(*probe_args).once.and_return(["4.98\n", '', status])
    expect(Open3).to receive(:capture3).with(*volume_args).once.and_return(['', 'max_volume: -60.0 dB', status])

    expect(analyzer.duration).to eq(4.98)
    expect(analyzer.max_volume).to eq(-60.0)
  end

  it 'does not measure volume when only duration is requested' do
    expect(Open3).to receive(:capture3).with(*probe_args).and_return(['1.0', '', status])
    expect(Open3).not_to receive(:capture3).with(*volume_args)
    expect(analyzer.duration).to eq(1.0)
  end

  it 'does not probe duration when only volume is requested' do
    expect(Open3).to receive(:capture3).with(*volume_args).and_return(['', 'max_volume: 0.0 dB', status])
    expect(Open3).not_to receive(:capture3).with(*probe_args)
    expect(analyzer.max_volume).to eq(0.0)
  end

  ['0', '-1', 'N/A', '5abc', '1e400'].each do |duration|
    it "rejects invalid duration #{duration.inspect}" do
      allow(Open3).to receive(:capture3).with(*probe_args).and_return([duration, '', status])
      expect { analyzer.duration }.to raise_error(described_class::DurationDetectionError)
    end
  end
end
