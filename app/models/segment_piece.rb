# A piece of a segment's text between two of the boundaries of the denotations on it (see
# MediaTranscript#segment_pieces): [begin, end) within the segment's text, without the spaces around it, and the
# denotations covering it, each of which covers the whole piece, as the segment is split at all their boundaries.
SegmentPiece = Data.define(:begin, :end, :text, :denotations) do
  class << self
    # `segment`'s pieces at the boundaries of `denotations`, those on it, with `segment_begin` where it begins in
    # the doc's body.
    def from_segment(segment, segment_begin, denotations)
      return [] if denotations.empty?

      # Each two boundaries next to each other make a piece, e.g. [0, 9, 19] to [0, 9] and [9, 19].
      piece_boundaries(segment, segment_begin, denotations).each_cons(2).filter_map do |from, to|
        segment_piece(segment, segment_begin, denotations, from, to)
      end
    end

    private

    # The offsets in `segment`'s text where it's split: the denotations' boundaries, and its beginning and end so the
    # text before the first denotation and after the last is a piece too, in order without duplicates.
    # `segment_begin` is where `segment` begins in the doc's body.
    def piece_boundaries(segment, segment_begin, denotations)
      denotation_boundaries = denotations.flat_map { [it.begin - segment_begin, it.end - segment_begin] }
      (denotation_boundaries + [0, segment.text.length]).uniq.sort
    end

    # The piece of `segment`'s text in [`from`, `to`) without the spaces around it, with the denotations covering
    # it, or nil for spaces only.
    def segment_piece(segment, segment_begin, denotations, from, to)
      raw = segment.text[from...to]
      text = raw.strip
      return if text.empty?

      piece_begin = from + raw.length - raw.lstrip.length
      piece_end = piece_begin + text.length
      covering = denotations.select { it.begin - segment_begin <= piece_begin && it.end - segment_begin >= piece_end }
      SegmentPiece.new(piece_begin, piece_end, text, covering)
    end
  end

  # The label of each denotation (see Denotation#label).
  def labels(user)
    denotations.map { it.label(user) }
  end
end
