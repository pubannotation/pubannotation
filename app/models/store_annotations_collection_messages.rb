# frozen_string_literal: true

class StoreAnnotationsCollectionMessages
  def initialize (job)
    @job = job
    @messages = []
  end

  def concat(messages)
    @messages.concat(messages)
  end

  def finalize
    return if @messages.empty?

    if @job
      @messages.each { |m| @job.add_message m }
    else
      raise ArgumentError, self.collect
    end
  end

  private

  def collect
    @messages.collect { |m| "[#{m[:sourcedb]}-#{m[:sourceid]}] #{m[:body]}" }.join("\n")
  end
end