module SegmentsHelper
  # Whether the current user can open SegmentsController for `doc`: one whose MediaTranscript has
  # segments (an image's has none), which the user can both access the media of and update.
  def segments_editable?(doc)
    current_user&.can_access_media? && doc.updatable_for?(current_user) && doc.media_transcript&.segments.present?
  end

  # A segment's playback time in ms as "m:ss.mmm", e.g. 61_234 as "1:01.234".
  def segment_time(ms)
    minutes, ms = ms.divmod(60_000)
    seconds, ms = ms.divmod(1000)
    format('%d:%02d.%03d', minutes, seconds, ms)
  end
end
