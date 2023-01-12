# frozen_string_literal: true

class AlignTextInRactor
  attr_reader :annotations_for_doc_collection, :messages

  def initialize(annotations_for_doc_collection, options)
    @annotations_for_doc_collection = annotations_for_doc_collection
    @options = options
    @messages = []
  end

  def call
    @annotations_for_doc_collection.each_with_index do |input_chunk, index|
      request = Request.new @options,
                            input_chunk.aligners,
                            index

      pipe.send(Ractor.make_shareable(request))
    end.each do
      _ractor, result = Ractor.select(*workers)

      # Ractor runs in parallel.
      # Results are returned in the order in which they were processed.
      # The order of the results is different from the order of the input.
      # The index of the input is used to retrieve the original data.
      input_chunk = @annotations_for_doc_collection[result.index_on_input]

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
          @messages << {
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

    self
  end

  private

  Request = Data.define(:options, :aligners, :index_on_input)
  Result = Data.define(:aligned_annotations, :index_on_input)

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
        while request = pipe.take
          alignedAnnotations = request.aligners.align_all request.options
          Ractor.yield(Ractor.make_shareable(Result.new(alignedAnnotations, request.index_on_input)))
        end
      end
    end
  end
end
