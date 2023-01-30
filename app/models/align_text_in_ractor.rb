# frozen_string_literal: true

class AlignTextInRactor
  Result = Data.define(:annotations_for_doc_collection, :messages)

  def initialize(annotations_for_doc_collection, options)
    @options = options
    @result = Result.new annotations_for_doc_collection, []
  end

  def call
    @result.annotations_for_doc_collection.each_with_index do |input_chunk, index|
      raw = Raw.new @options,
                    input_chunk.aligners,
                    index

      pipe.send(Ractor.make_shareable(raw))
    end.each do
      _ractor, result = Ractor.select(*workers)

      # Ractor runs in parallel.
      # Results are returned in the order in which they were processed.
      # The order of the results is different from the order of the input.
      # The index of the input is used to retrieve the original data.
      input_chunk = @result.annotations_for_doc_collection[result.index_on_input]

      result.aligned_annotations.each.with_index do |aligned_annotation, index|
        original_annotation = input_chunk.having_denotations_or_blocks[index]
        raise "[#{original_annotation[:sourcedb]}:#{original_annotation[:sourceid]}] #{aligned_annotation.error_message}" if aligned_annotation.error_message

        original_annotation.merge!({
                                     text: input_chunk.ref_text,
                                     denotations: aligned_annotation.denotations,
                                     blocks: aligned_annotation.blocks
                                   })
        original_annotation.delete_if { |_, v| !v.present? }

        if aligned_annotation.lost_annotations.present?
          @result.messages << {
            sourcedb: original_annotation[:sourcedb],
            sourceid: original_annotation[:sourceid],
            body: "Alignment failed. Invalid denotations found after transformation",
            data: {
              block_alignment: aligned_annotation.block_alignment,
              lost_annotations: aligned_annotation.lost_annotations
            }
          }
        end
      end
    end

    @result
  end

  private

  Raw = Data.define(:options, :aligners, :index_on_input)
  Aligned = Data.define(:aligned_annotations, :index_on_input)

  def pipe
    @pipe ||= Ractor.new do
      loop do
        Ractor.yield Ractor.receive
      end
    end
  end

  def workers
    @workers ||= (1..4).map do
      Ractor.new pipe do |pipe|
        while raw = pipe.take
          alignedAnnotations = raw.aligners.align_all raw.options
          Ractor.yield(Ractor.make_shareable(Aligned.new(alignedAnnotations, raw.index_on_input)))
        end
      end
    end
  end
end
