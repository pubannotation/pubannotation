class SimpleInlineTextAnnotation
  class Denotation
    attr_reader :span, :obj

    def initialize(begin_pos, end_pos, obj)
      @span = { begin: begin_pos, end: end_pos }
      @obj = obj
    end

    def begin_pos
      @span[:begin]
    end

    def end_pos
      @span[:end]
    end

    def to_h
      { span: @span, obj: @obj }
    end

    def nested_within?(other)
      other.begin_pos <= begin_pos && end_pos <= other.end_pos
    end

    def boundary_crossing?(other)
      starts_inside_other = begin_pos > other.begin_pos && begin_pos < other.end_pos
      ends_inside_other = end_pos > other.begin_pos && end_pos < other.end_pos

      starts_inside_other || ends_inside_other
    end
  end
end
