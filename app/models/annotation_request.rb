class AnnotationRequest
  attr_reader :hdocs, :doc, :error, :slice_count

  def initialize(hdocs:, doc:, error: nil, slice_count: nil)
    @hdocs = hdocs
    @doc = doc
    @error = error
    @slice_count = slice_count
  end
end
