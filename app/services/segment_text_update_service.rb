# Replaces the text of one segment of an audio/video Doc's MediaTranscript, and rebuilds the
# transcript's text and the Doc's body from the segments so all three stay in step. start_ms/end_ms
# are left as they are, and so are the Doc's denotations, even those after the edited segment.
class SegmentTextUpdateService
  def self.call(media_transcript, index, text)
    doc = media_transcript.doc
    raise ArgumentError, "Specified media transcript has no doc." unless doc
    raise ArgumentError, "No segment at index #{index}." unless (0...media_transcript.segments.size).cover?(index)
    raise ArgumentError, "Text is missing." if text.blank?
    # Rebuilding the body from the segments would otherwise discard an edit made to it directly.
    raise ArgumentError, "The doc's body no longer matches its media transcript." unless doc.body == media_transcript.speech_text

    segments = media_transcript.segments.dup
    segments[index] = segments[index].merge('text' => text.strip)
    media_transcript.segments = segments
    speech_text = media_transcript.speech_text

    MediaTranscript.transaction do
      media_transcript.update!(text: speech_text)
      doc.update!(body: speech_text)
    end
  end
end
