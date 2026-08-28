# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioTranscriptionService do
  let(:audio_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3').to_s }
  let(:model_path) { '/path/to/ggml-base.en.bin' }
  let(:ffprobe_args) do
    ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', audio_path]
  end

  around do |example|
    original_model_path = ENV['WHISPER_MODEL_PATH']
    original_cli_path = ENV['WHISPER_CLI_PATH']
    ENV['WHISPER_MODEL_PATH'] = model_path
    ENV.delete('WHISPER_CLI_PATH')
    example.run
  ensure
    ENV['WHISPER_MODEL_PATH'] = original_model_path
    ENV['WHISPER_CLI_PATH'] = original_cli_path
  end

  def stub_ffprobe(duration_seconds)
    success_status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(["#{duration_seconds}\n", '', success_status])
  end

  describe '#call' do
    before do
      allow(AudioSilenceDetector).to receive(:new).with(audio_path).and_return(instance_double(AudioSilenceDetector, silent?: false))
    end

    context 'when the audio is silent' do
      before do
        allow(AudioSilenceDetector).to receive(:new).with(audio_path).and_return(instance_double(AudioSilenceDetector, silent?: true))
      end

      it 'raises without invoking whisper-cli' do
        expect(Open3).not_to receive(:capture3).with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
        expect {
          described_class.new(audio_path).call
        }.to raise_error(ArgumentError, /silent/)
      end
    end

    context 'when whisper-cli succeeds' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = <<~TEXT
          [00:00:00.000 --> 00:00:03.500]   Ask not what your country
          [00:00:03.500 --> 00:00:06.000]   can do for you.
        TEXT
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        stub_ffprobe(6.0)
      end

      it 'returns the transcribed text with timed segments' do
        result = described_class.new(audio_path).call

        expect(result[:text]).to eq('Ask not what your country can do for you.')
        expect(result[:segments]).to eq(
          [
            { 'text' => 'Ask not what your country', 'start_ms' => 0, 'end_ms' => 3500 },
            { 'text' => 'can do for you.', 'start_ms' => 3500, 'end_ms' => 6000 }
          ]
        )
      end
    end

    context 'when a segment offset overruns the audio duration' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        stub_ffprobe(4.98)
      end

      it 'clamps start_ms and end_ms to the probed audio duration' do
        result = described_class.new(audio_path).call

        expect(result[:segments]).to eq([{ 'text' => 'Hello world.', 'start_ms' => 0, 'end_ms' => 4980 }])
      end
    end

    context 'when ffprobe fails to determine the duration' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        failure_status = instance_double(Process::Status, success?: false)
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(['', 'error', failure_status])
      end

      it 'leaves the raw offsets unclamped' do
        result = described_class.new(audio_path).call

        expect(result[:segments]).to eq([{ 'text' => 'Hello world.', 'start_ms' => 0, 'end_ms' => 30_000 }])
      end
    end

    context 'when ffprobe succeeds but reports the duration as N/A' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(["N/A\n", '', success_status])
      end

      it 'leaves the raw offsets unclamped instead of collapsing them to 0' do
        result = described_class.new(audio_path).call

        expect(result[:segments]).to eq([{ 'text' => 'Hello world.', 'start_ms' => 0, 'end_ms' => 30_000 }])
      end
    end

    context 'when ffprobe succeeds but reports a non-numeric duration' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(["5abc\n", '', success_status])
      end

      it 'leaves the raw offsets unclamped instead of misreading a partial number' do
        result = described_class.new(audio_path).call

        expect(result[:segments]).to eq([{ 'text' => 'Hello world.', 'start_ms' => 0, 'end_ms' => 30_000 }])
      end
    end

    context 'when ffprobe succeeds but reports the duration as Infinity' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(["Infinity\n", '', success_status])
      end

      it 'leaves the raw offsets unclamped instead of raising' do
        result = described_class.new(audio_path).call

        expect(result[:segments]).to eq([{ 'text' => 'Hello world.', 'start_ms' => 0, 'end_ms' => 30_000 }])
      end
    end

    context 'when WHISPER_CLI_PATH overrides the default binary' do
      before do
        ENV['WHISPER_CLI_PATH'] = '/opt/homebrew/bin/whisper-cli'
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:01.000]   transcript\n"
        allow(Open3).to receive(:capture3)
          .with('/opt/homebrew/bin/whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        stub_ffprobe(1.0)
      end

      it 'invokes the configured binary' do
        result = described_class.new(audio_path).call
        expect(result[:text]).to eq('transcript')
      end
    end

    context 'when whisper-cli fails' do
      before do
        failure_status = instance_double(Process::Status, success?: false, exitstatus: 2)
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return(['', "error: input file not found '#{audio_path}'", failure_status])
      end

      it 'raises an error including the exit status and stderr' do
        expect {
          described_class.new(audio_path).call
        }.to raise_error(/Whisper transcription failed \(status 2\).*input file not found/)
      end
    end
  end
end
