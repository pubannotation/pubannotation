class AudioSilenceDetector
  THRESHOLD_DB = -50.0

  def initialize(audio_path)
    @audio_path = audio_path
  end

  def silent?
    _stdout, stderr, _status = Open3.capture3('ffmpeg', '-i', @audio_path, '-af', 'volumedetect', '-f', 'null', '-')

    match = stderr.match(/max_volume:\s*(-?\d+(?:\.\d+)?)\s*dB/)
    return false unless match

    match[1].to_f < THRESHOLD_DB
  end
end
