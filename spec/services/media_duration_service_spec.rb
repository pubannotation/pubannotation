# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaDurationService do
  let(:media_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_video.mp4').to_s }
  let(:ffprobe_args) do
    ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', media_path]
  end

  def stub_ffprobe(stdout, success: true, stderr: '')
    status = instance_double(Process::Status, success?: success, exitstatus: success ? 0 : 1)
    allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return([stdout, stderr, status])
  end

  describe '.call' do
    it "returns ffprobe's duration in ms" do
      stub_ffprobe("12.3456\n")

      expect(described_class.call(media_path)).to eq(12_346)
    end

    it 'raises when ffprobe fails' do
      stub_ffprobe('', success: false, stderr: 'Invalid data found')

      expect { described_class.call(media_path) }
        .to raise_error(described_class::DurationDetectionError, /Failed to determine media duration via ffprobe.*Invalid data found/)
    end

    it 'raises when ffprobe reports a duration that is not a positive number' do
      stub_ffprobe("N/A\n")

      expect { described_class.call(media_path) }.to raise_error(described_class::DurationDetectionError)
    end
  end
end
