# A piece of a segment's text between two of the boundaries of the denotations on it (see
# MediaTranscript#segment_pieces): [begin, end) within the segment's text, without the spaces around it, and the
# denotations covering it, each of which covers the whole piece, as the segment is split at all their boundaries.
SegmentPiece = Data.define(:begin, :end, :text, :denotations) do
  # The label of each denotation (see Denotation#label).
  def labels(user)
    denotations.map { it.label(user) }
  end
end
