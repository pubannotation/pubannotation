class AudioTranscriptionService
  class TranscriptionError < StandardError; end

  # Each line of whisper-cli's `-np` output looks like:
  #   [00:00:00.000 --> 00:00:03.500]   Ask not what your country
  SEGMENT_LINE = /\A\[(\d{2}):(\d{2}):(\d{2})\.(\d{3}) --> (\d{2}):(\d{2}):(\d{2})\.(\d{3})\]\s*(.*)\z/

  def initialize(audio_path)
    @audio_path = audio_path
  end

  def call
    raise ArgumentError, "Audio file appears to be silent." if AudioSilenceDetector.new(@audio_path).silent?

    # Whisper pads the last segment of a chunk out to its 30s processing window rather than
    # the audio's actual end, so offsets are clamped against ffprobe's duration.
    parse_segments(transcribe, MediaDurationService.call(@audio_path))
  end

  private

  def transcribe
    cli_path   = ENV.fetch('WHISPER_CLI_PATH', 'whisper-cli')
    model_path = File.expand_path(ENV.fetch('WHISPER_MODEL_PATH'))

    # -np keeps stdout limited to the timestamped segment lines; diagnostics go to stderr.
    stdout, stderr, status = Open3.capture3(cli_path, '-m', model_path, '-f', @audio_path, '-np')
    raise TranscriptionError, "Whisper transcription failed (status #{status.exitstatus}): #{stderr.strip}" unless status.success?

    stdout
  end

  def parse_segments(stdout, duration_ms)
    segments = []

    stdout.each_line do |line|
      match = SEGMENT_LINE.match(line.strip)
      next unless match

      start_ms = timestamp_to_ms(match[1], match[2], match[3], match[4])
      # Whisper output is normally chronological, so once a segment starts past the audio's
      # actual end there's nothing legitimate left to parse.
      break if start_ms > duration_ms

      end_ms = clamp(timestamp_to_ms(match[5], match[6], match[7], match[8]), duration_ms)
      segments << { 'text' => match[9].strip, 'start_ms' => start_ms, 'end_ms' => end_ms }
    end

    segments
  end

  def timestamp_to_ms(hours, minutes, seconds, millis)
    ((hours.to_i * 3600 + minutes.to_i * 60 + seconds.to_i) * 1000) + millis.to_i
  end

  def clamp(value_ms, duration_ms)
    [value_ms, duration_ms].min
  end
end
