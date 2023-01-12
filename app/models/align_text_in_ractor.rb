# frozen_string_literal: true

class AlignTextInRactor
  attr_reader :annotation_with_documents, :messages

  def initialize(annotation_with_documents, options)
    @annotation_with_documents = annotation_with_documents
    @options = options
    @messages = []
  end

  def call
    @annotation_with_documents.each_with_index do |a_with_d, index|
      request = Request.new @options,
                            a_with_d.ref_text,
                            a_with_d.aligners,
                            index

      pipe.send(Ractor.make_shareable(request))
    end.each do
      _ractor, results = Ractor.select(*workers)

      a_with_d = @annotation_with_documents[results.index]
      results.aligned_annotations.each.with_index do |aligned_annotation, index|
        original_annotation = a_with_d.targets[index]
        raise "[#{original_annotation[:sourcedb]}:#{original_annotation[:sourceid]}] #{aligned_annotation.error_message}" if aligned_annotation.error_message

        original_annotation[:denotations] = aligned_annotation.denotations
        original_annotation[:blocks] = aligned_annotation.blocks
        original_annotation[:text] = a_with_d.ref_text
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
  end

  private

  Request = Data.define(:options, :ref_text, :data, :index)
  Results = Data.define(:aligned_annotations, :index)

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
          alignedAnnotations = AlignTextInRactor.align_data request.options,
                                                              request.ref_text,
                                                              request.data
          Ractor.yield(Ractor.make_shareable(Results.new(alignedAnnotations, request.index)))
        end
      end
    end
  end

  # The self of the block to be processed by Ractor is the running Ractor instance.
  # This method should be made a class method so that it can be called without reference to an instance of the AlignTextInRactor class.
  def self.align_data(options, ref_text, aligners)
    text_alignment = TextAlignment::TextAlignment.new(ref_text, options)
    aligners.map do |a|
      begin
        a.align(text_alignment)
      rescue => e
        break [AlignedAnnotation.new(nil, nil, nil, nil, e.message)]
      end
    end
  end
end
