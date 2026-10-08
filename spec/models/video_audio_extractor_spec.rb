# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VideoAudioExtractor do
  it 'extracts WAV audio to the caller-provided path and returns that path' do
    status = instance_double(Process::Status, success?: true)
    expect(Open3).to receive(:capture3)
      .with('ffmpeg', '-y', '-i', '/tmp/video.mp4', '-vn', '-f', 'wav', '/tmp/audio.wav')
      .and_return(['', '', status])

    expect(described_class.new('/tmp/video.mp4').extract_to('/tmp/audio.wav')).to eq('/tmp/audio.wav')
  end

  it 'reports extraction failures with stderr' do
    status = instance_double(Process::Status, success?: false)
    allow(Open3).to receive(:capture3).and_return(['', 'invalid data', status])

    expect { described_class.new('/tmp/video.mp4').extract_to('/tmp/audio.wav') }
      .to raise_error(described_class::ExtractionError, /Audio extraction failed: invalid data/)
  end
end
