class MediaDurationService
  class DurationDetectionError < StandardError; end

  # The media's duration in ms, via ffprobe (which reads video files' duration the same way).
  # `Float()` is used instead of `String#to_f` because `to_f` silently accepts garbage like "N/A"
  # or "5abc" as 0.0/5.0 instead of raising, and 0 is truthy in Ruby so a lenient parse wouldn't
  # even be caught by a nil check; `finite?` additionally guards against a numeric string large
  # enough to overflow to Infinity when parsed (e.g. "1e400"), which would otherwise raise
  # FloatDomainError when rounded.
  def self.call(media_path)
    stdout, stderr, status = Open3.capture3(
      'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1', media_path
    )
    raise DurationDetectionError, "Failed to determine media duration via ffprobe (status #{status.exitstatus}): #{stderr.strip}" unless status.success?

    duration_seconds = Float(stdout.strip)
    raise DurationDetectionError, "ffprobe reported an invalid media duration: #{stdout.strip.inspect}" unless duration_seconds.finite? && duration_seconds.positive?

    (duration_seconds * 1000).round
  rescue ArgumentError => e
    raise DurationDetectionError, e.message
  end
end
