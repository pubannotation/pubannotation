module SegmentsHelper
  # Whether to link to SegmentsController for `doc`, by the same decisions it opens the page with.
  def segments_listable?(doc)
    current_user&.can_access_media? && doc.segments_available?
  end

  # A segment's playback time in ms as "m:ss.mmm", e.g. 61_234 as "1:01.234".
  def segment_time(ms)
    minutes, ms = ms.divmod(60_000)
    seconds, ms = ms.divmod(1000)
    format('%d:%02d.%03d', minutes, seconds, ms)
  end

  # A segment's start and end times as "m:ss.mmm - m:ss.mmm", e.g. "0:00.000 - 0:03.000".
  def segment_time_range(segment)
    "#{segment_time(segment.start_ms)} - #{segment_time(segment.end_ms)}"
  end

  # The segments for the split editor to render, as JSON of their attributes and whether each is speech, as
  # only speech can be split.
  def split_segments_json(segments)
    segments.map do |segment|
      segment.as_json(only: %i[text start_ms end_ms line_break_after]).merge('speech' => segment.speech?)
    end.to_json
  end
end
