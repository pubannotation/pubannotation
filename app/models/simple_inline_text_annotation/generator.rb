class SimpleInlineTextAnnotation
  class Generator
    def initialize(source)
      @source = source
    end

    def generate
      text = @source[:text]
      denotations = standardize_denotations(@source[:denotations] || [])
      config = @source[:config]

      annotated_text = annotate_text(text, denotations, config)
      label_definitions = build_label_definitions(config)

      [annotated_text, label_definitions].compact.join("\n\n")
    end

    private

    # Only use the first denotation if the span range is the same.
    # Also sort denotations in descending for later annotation process.
    def standardize_denotations(denotations)
      denotations.uniq { |denotation| denotation[:span] }
                 .sort_by { |denotation| -denotation[:span][:begin] }
    end

    def annotate_text(text, denotations, config)
      denotations.each do |denotation|
        begin_pos = denotation[:span][:begin]
        end_pos = denotation[:span][:end]
        obj = get_obj(denotation[:obj], config)

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
