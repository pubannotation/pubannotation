class AudioSilenceDetector
  class DetectionError < StandardError; end

  THRESHOLD_DB = -50.0

  def initialize(audio_path)
    @audio_path = audio_path
  end

  def silent?
    _stdout, stderr, status = Open3.capture3('ffmpeg', '-i', @audio_path, '-af', 'volumedetect', '-f', 'null', '-')
    unless status.success?
      raise DetectionError, "Failed to analyze audio with ffmpeg (status #{status.exitstatus}): #{stderr.strip}"
    end

    # ffmpeg's volumedetect filter writes a line like this to stderr:
    #   [Parsed_volumedetect_0 @ 0x600001d50000] max_volume: -91.0 dB
    match = stderr.match(/max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB/)
    raise DetectionError, "Could not determine max_volume from ffmpeg output: #{stderr.strip}" unless match

    match[1].to_f < THRESHOLD_DB
  end
end
