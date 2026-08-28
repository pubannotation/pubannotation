class AudioTranscriptionService
  # Each line of whisper-cli's `-np` output looks like:
  #   [00:00:00.000 --> 00:00:03.500]   Ask not what your country
  SEGMENT_LINE = /\A\[(\d{2}):(\d{2}):(\d{2})\.(\d{3}) --> (\d{2}):(\d{2}):(\d{2})\.(\d{3})\]\s*(.*)\z/

  def initialize(audio_path)
    @audio_path = audio_path
  end

  def call
    raise ArgumentError, "Audio file appears to be silent." if AudioSilenceDetector.new(@audio_path).silent?

    cli_path   = ENV.fetch('WHISPER_CLI_PATH', 'whisper-cli')
    model_path = File.expand_path(ENV.fetch('WHISPER_MODEL_PATH'))

    # -np keeps stdout limited to the timestamped segment lines; diagnostics go to stderr.
    stdout, stderr, status = Open3.capture3(cli_path, '-m', model_path, '-f', @audio_path, '-np')
    raise "Whisper transcription failed (status #{status.exitstatus}): #{stderr.strip}" unless status.success?

    segments = parse_segments(stdout)
    { text: segments.map { |segment| segment['text'] }.join(' '), segments: }
  end

  private

  def parse_segments(stdout)
    duration_ms = audio_duration_ms

    stdout.each_line.filter_map do |line|
      match = SEGMENT_LINE.match(line.strip)
      next unless match

      start_ms = clamp(timestamp_to_ms(match[1], match[2], match[3], match[4]), duration_ms)
      end_ms = clamp(timestamp_to_ms(match[5], match[6], match[7], match[8]), duration_ms)

      { 'text' => match[9].strip, 'start_ms' => start_ms, 'end_ms' => end_ms }
    end
  end

  def timestamp_to_ms(hours, minutes, seconds, millis)
    ((hours.to_i * 3600 + minutes.to_i * 60 + seconds.to_i) * 1000) + millis.to_i
  end

  def clamp(value_ms, duration_ms)
    return value_ms unless duration_ms

    [value_ms, duration_ms].min
  end

  # Whisper pads the last segment of a chunk out to its 30s processing window rather than
  # the audio's actual end, so offsets are clamped against ffprobe's duration. A failed probe,
  # or one that can't determine the duration (ffprobe exits successfully but prints "N/A" for
  # some formats), just skips clamping instead of failing the whole transcription. `Float()` is
  # used instead of `String#to_f` because `to_f` silently accepts garbage like "N/A" or "5abc"
  # as 0.0/5.0 instead of raising, and 0 is truthy in Ruby so a lenient parse wouldn't even be
  # caught by a nil check; `finite?` additionally guards against "Infinity"/"NaN", which parse
  # fine but would otherwise raise FloatDomainError when rounded.
  def audio_duration_ms
    stdout, _stderr, status = Open3.capture3(
      'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1', @audio_path
    )
    return nil unless status.success?

    duration_seconds = Float(stdout.strip)
    return nil unless duration_seconds.finite? && duration_seconds.positive?

    (duration_seconds * 1000).round
  rescue ArgumentError, TypeError
    nil
  end
end
