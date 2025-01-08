class SimpleInlineTextAnnotation
  class Generator
    include DenotationValidator

    def initialize(source)
      @source = source.freeze
      @denotations = build_denotations(source[:denotations] || [])
    end

    def generate
      text = @source[:text]
      denotations = validate(@denotations)
      config = @source[:config]

      annotated_text = annotate_text(text, denotations, config)
      label_definitions = build_label_definitions(config)

      [annotated_text, label_definitions].compact.join("\n\n")
    end

    private

    def build_denotations(denotations)
      denotations.map { |d| Denotation.new(d[:span][:begin], d[:span][:end], d[:obj])}
    end

    def annotate_text(text, denotations, config)
      # Annotate text from the end to ensure position calculation.
      denotations.sort_by(&:begin_pos).reverse_each do |denotation|
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
