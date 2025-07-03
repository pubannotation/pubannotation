# frozen_string_literal: true

module TextAlign
  class AlignTextInRactor
    SendMessage = Data.define(:options, :aligners, :index_on_input)

    def initialize(annotations_for_doc_collection, options)
      @annotations_for_doc_collection = annotations_for_doc_collection
      @options = options
    end

    def call
      warnings = []

      @annotations_for_doc_collection.each_with_index do |input_chunk, index|
        pipe.send SendMessage.new(@options, input_chunk.aligners, index)
      end.each do
        _ractor, aligned = Ractor.select(*workers)

        # Ractor runs in parallel.
        # Results are returned in the order in which they were processed.
        # The order of the results is different from the order of the input.
        # The index of the input is used to retrieve the original data.
        input_chunk = @annotations_for_doc_collection[aligned.index_on_input]

        aligned.annotations.each.with_index do |aligned_annotation, index|
          original_annotation = input_chunk.having_denotations_or_blocks[index]
          raise "[#{original_annotation[:sourcedb]}:#{original_annotation[:sourceid]}] #{aligned_annotation.error_message}" if aligned_annotation.error_message

          original_annotation.merge!({
                                       text: input_chunk.ref_text,
                                       denotations: aligned_annotation.denotations.map {_1.dup},
                                       blocks: aligned_annotation.blocks.map {_1.dup}
                                     })
          original_annotation.delete_if { |_, v| !v.present? }

          if aligned_annotation.lost_annotations.present?
            warnings << {
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

      AlignedResults.new @annotations_for_doc_collection, warnings
    end

    private

    Aligned = Data.define(:annotations, :index_on_input)

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
          while sent = pipe.take
            alignedAnnotations = sent.aligners.align_all sent.options
            Ractor.yield Aligned.new(alignedAnnotations, sent.index_on_input)
          end
        end
      end
    end
  end
end