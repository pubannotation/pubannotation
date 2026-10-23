# Lets a Doc registered by hand with an audio/video Medium be highlighted and sought on its detail page
# like a transcribed Doc: gives it a MediaTranscript and, in its project, a Block for its speech (see
# MediaTranscript#speech_segment_blocks). With no timing to go on, the whole body becomes a single
# segment spanning the media's full duration.
class ManualDocPlaybackService
  # `doc` is expected to be already added to `project`.
  def self.call(project, doc)
    medium = doc.medium
    raise ArgumentError, "Specified media can't get a transcript." unless medium&.transcribable?

    duration_ms = medium.file.open { |file| (AudioAnalyzer.new(file.path).duration * 1000).round }
    # text is set explicitly, since deriving it would drop a body that looks like a Whisper
    # non-speech label (e.g. "(music)").
    media_transcript = MediaTranscript.create!(
      medium:,
      doc:,
      text: doc.body,
      segments: [Segment.new(sort_order: 0, text: doc.body, start_ms: 0, end_ms: duration_ms)]
    )

    segment_blocks = media_transcript.speech_segment_blocks
    project.instantiate_and_save_annotations({ blocks: segment_blocks }, doc) if segment_blocks.any?
  end
end
