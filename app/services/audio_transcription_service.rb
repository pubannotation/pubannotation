class AudioTranscriptionService
  def initialize(audio_path)
    @audio_path = audio_path
  end

  def call
    cli_path   = ENV.fetch('WHISPER_CLI_PATH', 'whisper-cli')
    model_path = File.expand_path(ENV.fetch('WHISPER_MODEL_PATH'))

    # -np/-nt keep stdout limited to the transcript itself; diagnostics go to stderr.
    stdout, stderr, status = Open3.capture3(cli_path, '-m', model_path, '-f', @audio_path, '-np', '-nt')
    raise "Whisper transcription failed (status #{status.exitstatus}): #{stderr.strip}" unless status.success?

    stdout.strip
  end
end
