class SimpleInlineTextAnnotation
  module DenotationValidator
    def validate(denotations, text_length)
      result = remove_duplicates_from(denotations)
      result = remove_non_integer_positions_from(result)
      result = remove_negative_positions_from(result)
      result = remove_invalid_positions_from(result)
      result = remove_out_of_bound_positions_from(result, text_length)
      result = remove_nests_from(result)
      remove_boundary_crosses_from(result)
    end

    private

    def remove_duplicates_from(denotations)
      denotations.uniq { |denotation| denotation.span }
    end

    def remove_non_integer_positions_from(denotations)
      denotations.reject { |denotation| denotation.position_not_integer? }
    end

    def remove_negative_positions_from(denotations)
      denotations.reject { |denotation| denotation.position_negative? }
    end

    def remove_invalid_positions_from(denotations)
      denotations.reject { |denotation| denotation.position_invalid? }
    end

    def remove_out_of_bound_positions_from(denotations, text_length)
      denotations.reject { |denotation| denotation.out_of_bounds?(text_length) }
    end

    def remove_nests_from(denotations)
      # Sort by begin_pos in ascending order. If begin_pos is the same, sort by end_pos in descending order.
      sorted_denotations = denotations.sort_by { |d| [d.begin_pos, -d.end_pos] }
      result = []

      sorted_denotations.each do |denotation|
        result << denotation unless result.any? { |outer| denotation.nested_within?(outer) }
      end

      result
    end

    def remove_boundary_crosses_from(denotations)
      denotations.reject do |denotation|
        denotations.any? { |existing| denotation.boundary_crossing?(existing) }
      end
    end
  end
end
