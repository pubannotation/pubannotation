class SimpleInlineTextAnnotation
  module DenotationStandardizer
    # Standardize denotations by removing duplicates, nested, and boundary-crossing spans.
    def standardize(denotations)
      result = remove_duplicates_from(denotations)
      result = remove_negative_positions_from(result)
      result = remove_invalid_positions_from(result)
      result = remove_nests_from(result)
      remove_boundary_crosses_from(result)
    end

    private

    def remove_duplicates_from(denotations)
      denotations.uniq { |denotation| denotation.span }
    end

    def remove_negative_positions_from(denotations)
      denotations.reject do |denotation|
        denotation.begin_pos < 0 || denotation.end_pos < 0
      end
    end

    def remove_invalid_positions_from(denotations)
      denotations.reject do |denotation|
        denotation.end_pos < denotation.begin_pos
      end
    end

    def remove_nests_from(denotations)
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
