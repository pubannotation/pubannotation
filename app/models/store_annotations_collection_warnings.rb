# frozen_string_literal: true

class StoreAnnotationsCollectionWarnings
  def initialize (job)
    @job = job
    @warnings = []
  end

  def concat(warnings)
    @warnings.concat(warnings)
  end

  def finalize
    return if @warnings.empty?

    if @job
      @warnings.each { |m| @job.add_message m }
    else
      raise ArgumentError, to_string
    end
  end

  private

  def to_string
    @warnings.collect do |m|
      "[#{m[:sourcedb]}-#{m[:sourceid]}] #{m[:body]}"
    end.join("\n")
  end
end