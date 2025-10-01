# Ractor-based parallel text alignment service
class ParallelTextAligner
  class << self
    def align_annotations(ref_text, annotations, options = {})
      # For now, fall back to regular alignment
      # TODO: Implement Ractor-based parallel alignment when Ractors are stable
      align_annotations_sequential(ref_text, annotations, options)
    end

    private

    def align_annotations_sequential(ref_text, annotations, options)
      aligner = Aligners.new(ref_text, annotations)
      aligner.align_all(options)
    rescue => e
      Rails.logger.error "Text alignment error: #{e.message}"
      # Return empty results to allow job to continue
      annotations.map { |ann| OpenStruct.new(denotations: [], blocks: [], error_message: e.message, lost_annotations: []) }
    end

    # Future Ractor implementation:
    # def align_annotations_parallel(ref_text, annotations, options)
    #   # Split annotations into chunks for parallel processing
    #   chunks = annotations.each_slice(10).to_a
    #
    #   # Create Ractors for each chunk
    #   ractors = chunks.map do |chunk|
    #     Ractor.new(ref_text, chunk, options) do |text, anns, opts|
    #       require_relative '../../../lib/text_alignment'
    #       aligner = Aligners.new(text, anns)
    #       aligner.align_all(opts)
    #     end
    #   end
    #
    #   # Collect results
    #   results = ractors.map(&:take).flatten
    #   results
    # end
  end
end