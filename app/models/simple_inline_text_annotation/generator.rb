class SimpleInlineTextAnnotation
  class Generator
    def initialize(source)
      @source = source
      @denotations = build_denotations(source[:denotations] || [])
    end

    def generate
      text = @source[:text]
      denotations = standardize_denotations(@denotations)
      config = @source[:config]

      annotated_text = annotate_text(text, denotations, config)
      label_definitions = build_label_definitions(config)

      [annotated_text, label_definitions].compact.join("\n\n")
    end

    private

    def build_denotations(denotations)
      denotations.map { |d| Denotation.new(d[:span][:begin], d[:span][:end], d[:obj])}
    end

    # Standardize denotations by removing duplicates, nested, and boundary-crossing spans.
    def standardize_denotations(denotations)
      result = remove_duplicates_from(denotations)
      result = remove_nesting_from(result)
      remove_boundary_crossing_from(result)
    end

    def remove_duplicates_from(denotations)
      denotations.uniq { |denotation| denotation.span }
    end

    def remove_nesting_from(denotations)
      sorted_denotations = denotations.sort_by { |d| [d.begin_pos, -d.end_pos] }
      result = []

      sorted_denotations.each do |denotation|
        unless result.any? { |r| r.begin_pos <= denotation.begin_pos && r.end_pos >= denotation.end_pos }
          result << denotation
        end
      end

      result
    end

    def remove_boundary_crossing_from(denotations)
      denotations.reject do |denotation|
        denotations.any? do |existing|
          boundary_crossing?(denotation, existing)
        end
      end
    end

    def boundary_crossing?(denotation, existing)
      is_start_of_denotation_span_between_existing_span =
        existing.begin_pos < denotation.begin_pos && denotation.begin_pos < existing.end_pos && existing.end_pos < denotation.end_pos

      is_end_of_denotation_span_between_existing_span =
        denotation.begin_pos < existing.begin_pos && existing.begin_pos < denotation.end_pos && denotation.end_pos < existing.end_pos

        is_start_of_denotation_span_between_existing_span || is_end_of_denotation_span_between_existing_span
    end

    def annotate_text(text, denotations, config)
      # Annotate text from the end to ensure position calculation.
      denotations.reverse_each do |denotation|
        begin_pos = denotation.begin_pos
        end_pos = denotation.end_pos
        obj = get_obj(denotation.obj, config)

        annotated_text = "[#{text[begin_pos...end_pos]}][#{obj}]"
        text = text[0...begin_pos] + annotated_text + text[end_pos..]
      end

      text
    end

    def get_obj(obj, config)
      return obj unless config && config[:"entity types"]

      entity = config[:"entity types"].find { |entity_type| entity_type[:id] == obj }
      entity ? entity[:label] : obj
    end

    def build_label_definitions(config)
      return nil unless config && config[:"entity types"]

      config[:"entity types"].map do |entity|
        "[#{entity[:label]}]: #{entity[:id]}"
      end.join("\n")
    end
  end
end
