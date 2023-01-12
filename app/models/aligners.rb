# frozen_string_literal: true

class Aligners
  def initialize(ref_text, annotations)
    @ref_text = ref_text
    @aligners = annotations.map do |annotation|
      Aligner.new annotation[:text],
                  annotation[:denotations],
                  annotation[:blocks]
    end
  end

  def align_all(options)
    text_alignment = TextAlignment::TextAlignment.new(@ref_text, options)
    @aligners.map do |a|
      begin
        a.align(text_alignment)
      rescue => e
        break [AlignedAnnotation.new(nil, nil, nil, nil, e.message)]
      end
    end
  end

  class Aligner
    def initialize(text, denotations, blocks)
      @text = text
      @denotations = denotations || []
      @blocks = blocks || []
    end

    def align(aligner)
      aligner.align(@text, @denotations + @blocks)

      AlignedAnnotation.new aligner.transform_hdenotations(@denotations),
                            aligner.transform_hdenotations(@blocks),
                            aligner.lost_annotations,
                            aligner.lost_annotations.present? ? aligner.block_alignment : nil
    end
  end

  class AlignedAnnotation
    attr_reader :denotations, :blocks, :lost_annotations, :block_alignments, :error_message

    def initialize(denotations, blocks, lost_annotations, block_alignments, error_message = nil)
      @denotations = denotations
      @blocks = blocks
      @lost_annotations = lost_annotations
      @block_alignments = block_alignments
      @error_message = error_message
    end
  end
end
