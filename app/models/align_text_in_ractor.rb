# frozen_string_literal: true

class AlignTextInRactor
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

              {
                denotations: aligner.transform_hdenotations(datum[:denotations]),
                blocks: aligner.transform_hdenotations(datum[:blocks]),
                lost_annotations: aligner.lost_annotations,
                block_alignment: aligner.lost_annotations.present? ? aligner.block_alignment : nil
              }
            rescue => e
              break {
                error: e.message
              }
            end
          end

          Ractor.yield(Ractor.make_shareable({
                                               index: msg.index,
                                               results: results
                                             }))
        end
      end
    end

    request = Data.define(:index, :ref_text, :options, :data)
    @annotations_for_doc_collection.each_with_index do |a_and_d, index|
      annotations, doc = a_and_d
      ref_text = doc&.original_body || doc.body
      targets = annotations.filter {|a| a[:denotations].present? || a[:blocks].present? }
      data = targets.map do |annotation|
        # align_hdenotations
        text = annotation[:text]
        denotations = annotation[:denotations] || []
        blocks = annotation[:blocks] || []

        {
          text: text,
          denotations: denotations,
          blocks: blocks
        }
      end

      pipe.send(Ractor.make_shareable(request.new(index, ref_text, @options, data)))
    end.each do
      _r, results = Ractor.select(*workers)

      annotations, doc = annotations_for_doc_collection[results[:index]]
      ref_text = doc&.original_body || doc.body
      targets = annotations.filter {|a| a[:denotations].present? || a[:blocks].present? }

      @messages << results[:results].map.with_index do |result, i|
        annotation = targets[i]

        if result[:error]
          raise "[#{annotation[:sourcedb]}:#{annotation[:sourceid]}] #{result[:error].message}"
        else
          annotation[:denotations] = result[:denotations]
          annotation[:blocks] = result[:blocks]
          annotation[:text] = ref_text
          annotation.delete_if{|k,v| !v.present?}

          if result[:lost_annotations].present?
            {
              sourcedb: annotation[:sourcedb],
              sourceid: annotation[:sourceid],
              body:"Alignment failed. Invalid denotations found after transformation",
              data:{
                block_alignment: result[:block_alignment],
                lost_annotations: result[:lost_annotations]
              }
            }
          else
            nil
          end
        end
      end.compact
    end
  end
end
