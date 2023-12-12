# frozen_string_literal: true

# Validated annotations in JSON format received from external sources
class ValidatedAnnotations
  attr_reader :annotations, :sourcedb_sourceid_index

  def initialize(json_string)
    parsed_json = parse json_string

    validate! parsed_json
    @annotations = normalize parsed_json
    @sourcedb_sourceid_index = DocumentSourceIndex.new @annotations
  end

  private

  def parse(json_string)
    # To return the annotation in an array
    parsed_json = begin
      JSON.parse(json_string, symbolize_names: true)
    rescue JSON::ParserError => e
      raise ArgumentError, "JSON parse error. Not a valid JSON object: " + e.message
    end

    raise ArgumentError, "JSON array is not a valid format for annotation." if parsed_json.class == Array
    [parsed_json]
  end

  def validate!(annotations)
    annotations.each do |annotation|
      unless annotation[:sourcedb].present? && annotation[:sourceid].present?
        raise ArgumentError, "sourcedb and/or sourceid not specified."
      end
    end
  end

  def normalize(annotations)
    annotations.map { AnnotationUtils.normalize! _1 }
  end
end
