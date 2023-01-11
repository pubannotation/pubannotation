# frozen_string_literal: true

class AlignTextInRactor
  Results = Data.define(:index, :processed_annotations)

  class ProcessedAnnotation
    attr_reader :denotations, :blocks, :lost_annotations, :block_alignments, :error_message

    def initialize(denotations, blocks, lost_annotations, block_alignments, error_message = nil)
      @denotations = denotations
      @blocks = blocks
      @lost_annotations = lost_annotations
      @block_alignments = block_alignments
      @error_message = error_message
    end
  end

  attr_reader :annotations_for_doc_collection, :messages

  def initialize(annotations_for_doc_collection, options)
    @annotations_for_doc_collection = annotations_for_doc_collection
    @options = options
    @messages = []
  end

  def call
    pipe = Ractor.new do
      loop do
        Ractor.yield Ractor.receive
      end
    end

    workers = (1..4).map do
      Ractor.new pipe do |pipe|
        while msg = pipe.take
          aligner = TextAlignment::TextAlignment.new(msg.ref_text, msg.options)
          results = msg.data.map do |datum|
            begin
              aligner.align(datum[:text], datum[:denotations] + datum[:blocks])

              ProcessedAnnotation.new aligner.transform_hdenotations(datum[:denotations]),
                                      aligner.transform_hdenotations(datum[:blocks]),
                                      aligner.lost_annotations,
                                      aligner.lost_annotations.present? ? aligner.block_alignment : nil
            rescue => e
              break ProcessedAnnotation.new(nil, nil, nil, nil, e.message)
            end
          end

          Ractor.yield(Ractor.make_shareable(Results.new(msg.index, results)))
        end
      end
    end

    request = Data.define(:index, :ref_text, :options, :data)
    @annotations_for_doc_collection.each_with_index do |a_with_d, index|
      pipe.send(Ractor.make_shareable(request.new(index, a_with_d.ref_text, @options, a_with_d.target_data)))
    end.each do
      _r, results = Ractor.select(*workers)

      a_with_d = @annotations_for_doc_collection[results.index]
      results.processed_annotations.each.with_index do |processed_annotation, index|
        original_annotation = a_with_d.targets[index]
        raise "[#{original_annotation[:sourcedb]}:#{original_annotation[:sourceid]}] #{processed_annotation.error_message}" if processed_annotation.error_message

        original_annotation[:denotations] = processed_annotation.denotations
        original_annotation[:blocks] = processed_annotation.blocks
        original_annotation[:text] = a_with_d.ref_text
        original_annotation.delete_if { |_, v| !v.present? }

        if processed_annotation.lost_annotations.present?
          @messages << {
            sourcedb: original_annotation[:sourcedb],
            sourceid: original_annotation[:sourceid],
            body: "Alignment failed. Invalid denotations found after transformation",
            data: {
              block_alignment: processed_annotation.block_alignment,
              lost_annotations: processed_annotation.lost_annotations
            }
          }
        end
      end
    end
  end
end
