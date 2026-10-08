# Analyzes local audio files without depending on Active Storage blobs.
class AudioAnalyzer
  class DurationDetectionError < StandardError; end
  class VolumeDetectionError < StandardError; end

  def initialize(audio_path)
    @audio_path = audio_path
  end

  # Duration in seconds and maximum volume in dB.
  def metadata
    { duration: duration, max_volume: max_volume }
  end

  # Use container duration, which is also available when stream duration is missing.
  def duration
    stdout, stderr, status = Open3.capture3(
      'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1', @audio_path
    )
    raise DurationDetectionError, "Failed to determine audio duration via ffprobe (status #{status.exitstatus}): #{stderr.strip}" unless status.success?

    # Strict parsing and validation prevent invalid durations from corrupting timestamps.
    duration_seconds = Float(stdout.strip)
    raise DurationDetectionError, "ffprobe reported an invalid audio duration: #{stdout.strip.inspect}" unless duration_seconds.finite? && duration_seconds.positive?

    duration_seconds
  rescue ArgumentError => e
    raise DurationDetectionError, e.message
  end

  def max_volume
    _stdout, stderr, status = Open3.capture3('ffmpeg', '-i', @audio_path, '-af', 'volumedetect', '-f', 'null', '-')
    unless status.success?
      raise VolumeDetectionError, "Failed to analyze audio with ffmpeg (status #{status.exitstatus}): #{stderr.strip}"
    end

    # volumedetect writes its measurements to stderr.
    match = stderr.match(/max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB/)
    raise VolumeDetectionError, "Could not determine max_volume from ffmpeg output: #{stderr.strip}" unless match

    Float(match[1])
  end
end
