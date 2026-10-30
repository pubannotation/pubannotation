# frozen_string_literal: true

class DocumentFetcher
  class << self
    # Returns [documents, messages].
    def fetch(sourcedb, sourceids)
      raise ArgumentError, "sourcedb is empty" unless sourcedb.present?
      raise ArgumentError, "sourceids is empty" unless sourceids.present?

      begin
        sequencer = Sequencer.find(sourcedb)
      rescue ActiveRecord::ActiveRecordError
        raise ArgumentError, "User documents cannot be automatically obtained. Please upload them yourself." if sourcedb.include?('@')
        raise ArgumentError, "Could not find the sequencer for the sourcedb: [#{sourcedb}]"
      end

      docs, messages = sequencer.get_docs(sourceids)

      invalid_docs = docs.select{|doc| !valid_document?(doc)}
      invalid_docs.each do |doc|
        messages << {sourcedb:sourcedb, sourceid:[doc[:sourceid]], body:"Invalid document entry."}
      end

      docs -= invalid_docs

      [docs, messages]
    end

    private

    def valid_document?(hdoc)
      return false unless hdoc[:text].present?
      return false unless hdoc[:sourcedb].present?
      return false unless hdoc[:sourceid].present?
      true
    end
  end
end
