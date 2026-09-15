class MediaTranscript < ApplicationRecord
  # `medium` is stored directly (not via doc/media_transcription_task) since both associations
  # are optional: a Doc never exists for a no-speech result, and MediaTranscriptionTask can be
  # cleaned up independently (dependent: :nullify). A Doc, once linked, is not severable the
  # same way (Doc has_one :media_transcript, dependent: :destroy).
  belongs_to :medium
  belongs_to :media_transcription_task, optional: true
  belongs_to :doc, optional: true

  # `text` is the plain-text Doc body (an image caption, or the resolved speech transcript for
  # audio/video); nullable since populating it is up to the caller/media type. A new record
  # built with `segments` but no explicit `text` gets one derived below.
  #
  # `segments` is an array of timed transcript segments, each a hash with 'text' (String, may
  # be a non-speech label — see NonSpeechTextMatcher), 'start_ms', 'end_ms' (non-negative
  # Integers, start <= end, interval [start_ms, end_ms)), and 'char_begin'/'char_end' (the
  # offsets, into `text`, of this segment's contribution to it — nil for non-speech segments,
  # which contribute nothing to `text`). Segments must be chronological and non-overlapping
  # (enforced below); images leave this at its default empty array.
  validates :media_transcription_task_id, uniqueness: true, allow_nil: true
  validates :doc_id, uniqueness: true, allow_nil: true
  validate :doc_has_matching_medium
  validate :segments_are_valid

  # Derives `text` from segments for a new record, unless already set explicitly (e.g. an
  # image's caption), and rewrites `segments` in place with each one's char_begin/char_end
  # into that `text`. Skipped for records loaded from the database. Requires `segments` to be
  # passed to .new(...) itself, not assigned afterward (e.g. record.segments = [...]), since
  # this runs once, right after construction — MediaTextGenerationService does this correctly,
  # but FactoryBot does not, so specs relying on this must build with MediaTranscript.new
  # directly rather than the :media_transcript factory.
  after_initialize do
    if new_record? && segments.present?
      self.segments = segments_with_char_offsets
      self.text ||= speech_text
    end
  end

  # Segments that are actual speech, excluding Whisper's non-speech labels (e.g. "(music)").
  # Kept rather than discarded in `segments`, since the raw transcript may still be useful.
  def speech_segments
    segments.select { |segment| valid_segment?(segment) }
            .reject { |segment| NonSpeechTextMatcher.match?(segment['text']) }
  end

  def speech_text
    speech_segments.pluck('text').join(' ')
  end

  # `segments`, with each speech segment's char_begin/char_end set to its offset into what
  # #speech_text would build from them (one space between consecutive speech segments' text,
  # regardless of how many non-speech segments sit between them in `segments`). Non-speech and
  # malformed segments are passed through with char_begin/char_end set to nil, since they
  # contribute nothing to that text.
  def segments_with_char_offsets
    char_position = 0

    segments.map do |segment|
      next segment unless valid_segment?(segment)
      next segment.merge('char_begin' => nil, 'char_end' => nil) if NonSpeechTextMatcher.match?(segment['text'])

      char_begin = char_position
      char_end = char_begin + segment['text'].length
      char_position = char_end + 1 # +1 for the space #speech_text joins consecutive segments with

      segment.merge('char_begin' => char_begin, 'char_end' => char_end)
    end
  end

  private

  def doc_has_matching_medium
    errors.add(:doc, 'must have the same medium as this transcript') if doc && doc.medium != medium
  end

  def segments_are_valid
    return errors.add(:segments, 'must be an array') unless segments.is_a?(Array)

    previous_end_ms = nil

    segments.each_with_index do |segment, index|
      unless valid_segment?(segment)
        errors.add(:segments, "at index #{index} must be a hash with a 'text' string, non-negative integer " \
                               "'start_ms'/'end_ms' where start_ms <= end_ms, and 'char_begin'/'char_end' that " \
                               "are each either nil or a non-negative integer")
        next
      end

      errors.add(:segments, "at index #{index} overlaps the previous segment: start_ms must be >= the previous end_ms") if
        previous_end_ms && segment['start_ms'] < previous_end_ms

      previous_end_ms = segment['end_ms']
    end
  end

  def valid_segment?(segment)
    segment.is_a?(Hash) &&
      segment['text'].is_a?(String) &&
      segment['start_ms'].is_a?(Integer) && segment['start_ms'] >= 0 &&
      segment['end_ms'].is_a?(Integer) && segment['end_ms'] >= segment['start_ms'] &&
      valid_char_offset?(segment['char_begin']) &&
      valid_char_offset?(segment['char_end'])
  end

  def valid_char_offset?(value)
    value.nil? || (value.is_a?(Integer) && value >= 0)
  end
end
