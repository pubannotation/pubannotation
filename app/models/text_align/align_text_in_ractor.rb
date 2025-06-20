# frozen_string_literal: true

module TextAlign
  class AlignTextInRactor
    SendMessage = Data.define(:options, :aligners, :index_on_input)
    RACTOR_COUNT = 2

    def initialize(annotations_for_doc_collection, options)
      @annotations_for_doc_collection = annotations_for_doc_collection
      @options = options
    end

    def call
      warnings = []

      @annotations_for_doc_collection.each_with_index do |input_chunk, index|
        workers[index % RACTOR_COUNT].send(send_message_for(index, input_chunk))
      end

        # Ractor runs in parallel.
        # Results are returned in the order in which they were processed.
        # The order of the results is different from the order of the input.
        # The index of the input is used to retrieve the original data.

      @annotations_for_doc_collection.size.times do
        _ractor, aligned = Ractor.select(port)
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

    def send_message_for(index, input_chunk)
      m = SendMessage.new(@options, input_chunk.aligners, index)
      Ractor.make_shareable(m)
    end

    def port
      @port ||= Ractor::Port.new
    end

    def workers
      @workers ||= (1..RACTOR_COUNT).map do
        Ractor.new(port) do |job_port|
          while job = Ractor.receive
            alignedAnnotations = job.aligners.align_all(job.options)
            job_port.send(Ractor.make_shareable(Aligned.new(alignedAnnotations, job.index_on_input)))
          end
        end
      end
    end
  end
end
