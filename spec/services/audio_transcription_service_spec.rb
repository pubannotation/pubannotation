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

  describe '.generation_model' do
    it "is WHISPER_MODEL_PATH's file name, without .bin, prefixed with whisper:" do
      expect(described_class.generation_model).to eq('whisper:ggml-base.en')
    end
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

      it 'returns the timed segments' do
        result = described_class.new(audio_path).call

        expect(result).to eq(
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

      it 'clamps end_ms to the probed audio duration' do
        result = described_class.new(audio_path).call

        expect(result).to eq([{ 'text' => 'Hello world.', 'start_ms' => 0, 'end_ms' => 4980 }])
      end
    end

    context 'when a segment starts entirely past the audio duration' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = <<~TEXT
          [00:00:00.000 --> 00:00:03.500]   Ask not what your country
          [00:00:05.000 --> 00:00:06.000]   can do for you.
        TEXT
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        stub_ffprobe(3.5)
      end

      it 'stops parsing instead of including the trailing out-of-range segment' do
        result = described_class.new(audio_path).call

        expect(result).to eq(
          [{ 'text' => 'Ask not what your country', 'start_ms' => 0, 'end_ms' => 3500 }]
        )
      end
    end

    context 'when ffprobe fails to determine the duration' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        failure_status = instance_double(Process::Status, success?: false, exitstatus: 1)
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(['', 'error', failure_status])
      end

      it 'raises instead of returning an unclamped transcription' do
        expect {
          described_class.new(audio_path).call
        }.to raise_error(AudioTranscriptionService::DurationDetectionError, /Failed to determine audio duration via ffprobe/)
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

      it 'raises instead of collapsing the offsets to 0' do
        expect {
          described_class.new(audio_path).call
        }.to raise_error(AudioTranscriptionService::DurationDetectionError)
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

      it 'raises instead of misreading a partial number' do
        expect {
          described_class.new(audio_path).call
        }.to raise_error(AudioTranscriptionService::DurationDetectionError)
      end
    end

    context 'when ffprobe is not installed' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_raise(Errno::ENOENT, 'ffprobe')
      end

      it 'raises instead of silently skipping duration clamping' do
        expect {
          described_class.new(audio_path).call
        }.to raise_error(Errno::ENOENT)
      end
    end

    context 'when ffprobe succeeds but reports a duration that overflows to Infinity' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        stdout = "[00:00:00.000 --> 00:00:30.000]   Hello world.\n"
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np')
          .and_return([stdout, '', success_status])
        allow(Open3).to receive(:capture3).with(*ffprobe_args).and_return(["1e400\n", '', success_status])
      end

      it 'raises instead of later raising FloatDomainError from rounding' do
        expect {
          described_class.new(audio_path).call
        }.to raise_error(AudioTranscriptionService::DurationDetectionError, /ffprobe reported an invalid audio duration/)
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
        expect(result).to eq([{ 'text' => 'transcript', 'start_ms' => 0, 'end_ms' => 1000 }])
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
        }.to raise_error(AudioTranscriptionService::TranscriptionError, /Whisper transcription failed \(status 2\).*input file not found/)
      end
    end
  end
end
