class AudioSilenceDetector

  THRESHOLD_DB = -50.0

  def initialize(audio_path)
    @audio_path = audio_path
  end

  def silent?
    AudioAnalyzer.new(@audio_path).max_volume < THRESHOLD_DB
  end
end
