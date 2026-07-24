# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AudioTranscriptionService do
  let(:audio_path) { Rails.root.join('spec', 'fixtures', 'files', 'test_audio.mp3').to_s }
  let(:model_path) { '/path/to/ggml-base.en.bin' }

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

  describe '#call' do
    context 'when whisper-cli succeeds' do
      before do
        success_status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np', '-nt')
          .and_return([" Ask not what your country can do for you.\n", '', success_status])
      end

      it 'returns the transcribed text' do
        result = described_class.new(audio_path).call
        expect(result).to eq('Ask not what your country can do for you.')
      end
    end

    context 'when WHISPER_CLI_PATH overrides the default binary' do
      before do
        ENV['WHISPER_CLI_PATH'] = '/opt/homebrew/bin/whisper-cli'
        success_status = instance_double(Process::Status, success?: true)
        allow(Open3).to receive(:capture3)
          .with('/opt/homebrew/bin/whisper-cli', '-m', model_path, '-f', audio_path, '-np', '-nt')
          .and_return(['transcript', '', success_status])
      end

      it 'invokes the configured binary' do
        result = described_class.new(audio_path).call
        expect(result).to eq('transcript')
      end
    end

    context 'when whisper-cli fails' do
      before do
        failure_status = instance_double(Process::Status, success?: false, exitstatus: 2)
        allow(Open3).to receive(:capture3)
          .with('whisper-cli', '-m', model_path, '-f', audio_path, '-np', '-nt')
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
