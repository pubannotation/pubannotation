# A piece of a segment's text between two of the boundaries of the denotations on it (see
# MediaTranscript#segment_pieces): [begin, end) within the segment's text, without the spaces around it, and the
# denotations covering it, each of which covers the whole piece, as the segment is split at all their boundaries.
SegmentPiece = Data.define(:begin, :end, :text, :denotations) do
  # Each denotation as "project: obj", or, for one in a project whose annotations `user` can't access, only that
  # it's there.
  def labels(user)
    denotations.map do |denotation|
      project = denotation.project
      project.annotations_accessible?(user) ? "#{project.name}: #{denotation.obj}" : '(private project)'
    end
  end
end
