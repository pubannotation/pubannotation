module SegmentsHelper
  # Whether to link to SegmentsController for `doc`, by the same decisions it opens the page with.
  def segments_listable?(doc)
    current_user&.can_access_media? && doc.segment_listable_by?(current_user)
  end

  # A segment's playback time in ms as "m:ss.mmm", e.g. 61_234 as "1:01.234".
  def segment_time(ms)
    minutes, ms = ms.divmod(60_000)
    seconds, ms = ms.divmod(1000)
    format('%d:%02d.%03d', minutes, seconds, ms)
  end
end
