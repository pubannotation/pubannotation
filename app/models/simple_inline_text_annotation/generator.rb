class SimpleInlineTextAnnotation
  class Generator
    include DenotationValidator

    def initialize(source)
      @source = source.dup.freeze
      @denotations = build_denotations(source["denotations"] || [])
      @config = @source["config"]
    end

    def generate
      text = @source["text"]
      raise SimpleInlineTextAnnotation::GeneratorError, 'The "text" key is missing.' if text.nil?
      denotations = validate(@denotations)

      annotated_text = annotate_text(text, denotations)
      label_definitions = build_label_definitions

      [annotated_text, label_definitions].compact.join("\n\n")
    end

    private

    def build_denotations(denotations)
      denotations.map { |d| Denotation.new(d["span"]["begin"], d["span"]["end"], d["obj"]) }
    end

    def annotate_text(text, denotations)
      # Annotate text from the end to ensure position calculation.
      denotations.sort_by(&:begin_pos).reverse_each do |denotation|
        begin_pos = denotation.begin_pos
        end_pos = denotation.end_pos
        obj = get_obj(denotation.obj)

        annotated_text = "[#{text[begin_pos...end_pos]}][#{obj}]"
        text = text[0...begin_pos] + annotated_text + text[end_pos..]
      end

      text
    end

    def entity_types
      @config ? @config["entity types"] : nil
    end

    def get_obj(obj)
      return obj unless entity_types

      entity = entity_types.find { |entity_type| entity_type["id"] == obj }
      entity ? entity["label"] : obj
    end

    def build_label_definitions
      return nil unless entity_types

      entity_types.map do |entity|
        "[#{entity["label"]}]: #{entity["id"]}"
      end.join("\n")
    end
  end
end
