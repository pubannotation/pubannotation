# frozen_string_literal: true

# Validated annotations in JSON format received from external sources
class ValidatedAnnotations
  attr_reader :annotations, :sourcedb_sourceid_index

  def initialize(json_string)
    parsed_json = parse json_string
    validate! parsed_json
    @annotations = normalize parsed_json
    @sourcedb_sourceid_index = build_index @annotations
  end

  private

  def parse(json_string)
    # To return the annotation in an array
    Array(JSON.parse(json_string, symbolize_names: true))
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

  def build_index(annotations)
    annotation = annotations.shift
    index = DocumentSourceIndex.new(annotation[:sourcedb], [annotation[:sourceid]])

    annotations.each do |annotation|
      index.merge DocumentSourceIndex.new(annotation[:sourcedb], [annotation[:sourceid]])
    end

    index
  end
end
