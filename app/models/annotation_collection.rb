class AnnotationCollection
  attr_reader :annotations, :sourcedb, :sourceid

  def initialize(json_file_path)
    @annotations = load_from json_file_path
    set_sourcedb_and_sourceid @annotations
    validate_and_normalize! @annotations
  end

  private

  def load_from(json_file_path)
    json = File.read(json_file_path)
    o = JSON.parse(json, symbolize_names: true)

    # To return the annotation in an array
    o.is_a?(Array) ? o : [o]
  rescue JSON::ParserError
    raise "[#{File.basename(json_file_path)}] JSON parse error. Not a valid JSON object."
  end

  def set_sourcedb_and_sourceid(annotations)
    annotation = annotations.first
    raise ArgumentError, "sourcedb and/or sourceid not specified." unless annotation[:sourcedb].present? && annotation[:sourceid].present?
    @sourcedb = annotation[:sourcedb]
    @sourceid = annotation[:sourceid]
  end

  def validate_and_normalize!(annotations)
    annotations.each do |annotation|
      raise ArgumentError, "One json file has to include annotations to the same document." if (annotation[:sourcedb] != @sourcedb) || (annotation[:sourceid] != @sourceid)

      AnnotationUtils.normalize!(annotation)
    end
  end
end
