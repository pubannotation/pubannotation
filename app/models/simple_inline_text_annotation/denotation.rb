class SimpleInlineTextAnnotation
  class Denotation
    def initialize(begin_pos, end_pos, obj)
      @span = { begin: begin_pos, end: end_pos }
      @obj = obj
    end

    def to_h
      { span: @span, obj: @obj }
    end
  end
end
