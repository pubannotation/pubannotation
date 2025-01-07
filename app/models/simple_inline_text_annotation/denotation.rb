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
  end
end
