module SegmentsHelper
  # Whether to link to SegmentsController for `doc`, by the same decision it opens the page with.
  def segments_editable?(doc)
    doc.segments_listable_by?(current_user)
  end

  # A segment's playback time in ms as "m:ss.mmm", e.g. 61_234 as "1:01.234".
  def segment_time(ms)
    minutes, ms = ms.divmod(60_000)
    seconds, ms = ms.divmod(1000)
    format('%d:%02d.%03d', minutes, seconds, ms)
  end
end
