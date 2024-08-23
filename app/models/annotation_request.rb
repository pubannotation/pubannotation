class AnnotationRequest
  attr_reader :hdocs, :doc, :error, :slice_count

  def initialize(hdocs, doc:, slice_count: nil, error: nil)
    @hdocs = hdocs
    @doc = doc
    @slice_count = slice_count
    @error = error
  end
end
