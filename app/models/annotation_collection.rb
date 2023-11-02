class AnnotationCollection
  attr_reader :annotations, :sourcedb_sourceid_index

  def initialize(json_string)
    @annotations = parse json_string
    set_sourcedb_and_sourceid @annotations
    validate_and_normalize! @annotations
  end

  private

  def parse(json_string)
    # To return the annotation in an array
    Array(JSON.parse(json_string, symbolize_names: true))
  end

  def set_sourcedb_and_sourceid(annotations)
    annotation = annotations.shift
    raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotation[:sourcedb].present? && annotation[:sourceid].present?
    @sourcedb_sourceid_index = DocumentSourceIndex.new(annotation[:sourcedb], [annotation[:sourceid]])

    annotations.each do |annotation|
      raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotation[:sourcedb].present? && annotation[:sourceid].present?
      @sourcedb_sourceid_index.merge DocumentSourceIndex.new(annotation[:sourcedb], [annotation[:sourceid]])
    end
  end

  def validate_and_normalize!(annotations)
    annotations.each do |annotation|
      AnnotationUtils.normalize!(annotation)
    end
  end
end
