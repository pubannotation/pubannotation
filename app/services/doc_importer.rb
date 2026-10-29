# frozen_string_literal: true

class DocImporter
  class << self
    def hdoc_valid?(hdoc)
      return false unless hdoc[:text].present?
      return false unless hdoc[:sourcedb].present?
      return false unless hdoc[:sourceid].present?
      true
    end

    # Returns [documents, messages].
    def fetch(sourcedb, sourceids)
      raise ArgumentError, "sourcedb is empty" unless sourcedb.present?
      raise ArgumentError, "sourceids is empty" unless sourceids.present?

      begin
        sequencer = Sequencer.find(sourcedb)
      rescue ActiveRecord::ActiveRecordError => e
        raise ArgumentError, "User documents cannot be automatically obtained. Please upload them yourself." if sourcedb.include?('@')
        raise ArgumentError, "Could not find the sequencer for the sourcedb: [#{sourcedb}]"
      end

      docs, messages = sequencer.get_docs(sourceids)

      invalid_docs = docs.select{|doc| !hdoc_valid?(doc)}
      invalid_docs.each do |doc|
        messages << {sourcedb:sourcedb, sourceid:[doc[:sourceid]], body:"Invalid document entry."}
      end

      docs -= invalid_docs

      [docs, messages]
    end

    def store!(hdoc)
      hdoc[:text] = hdoc[:body] if !hdoc[:text] && hdoc[:body]

      doc = nil
      # Use shorter transaction to reduce lock contention
      ActiveRecord::Base.transaction(isolation: :read_committed) do
        doc = Doc.create!(
          {
            body: hdoc[:text],
            sourcedb: hdoc[:sourcedb],
            sourceid: hdoc[:sourceid],
            source: hdoc[:source],
            medium_id: hdoc[:medium_id]
          }
        )
        doc.store_divisions(hdoc[:divisions]) if hdoc.has_key? :divisions
        doc.store_typesettings(hdoc[:typesettings]) if hdoc.has_key? :typesettings
      end

      doc
    end

    def store(hdoc)
      begin
        store!(hdoc)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        if e.message.include?("already been taken") || e.message.include?("duplicate") || e.message.include?("unique")
          # Document was created by another job (race condition) - find and return it
          Doc.find_by(sourcedb: hdoc[:sourcedb], sourceid: hdoc[:sourceid])
        else
          raise e
        end
      end
    end

    def store_many(hdocs)
      docs_saved = []
      messages = []

      hdocs.each do |hdoc|
        doc = store(hdoc)
        docs_saved << doc if doc  # Only add if doc was created/found
      rescue => e
        messages << {sourcedb:hdoc[:sourcedb], sourceid:[hdoc[:sourceid]], body:e.message}
      end

      [docs_saved, messages]
    end

    def import!(sourcedb, sourceid)
      docs, messages = fetch(sourcedb, [sourceid])
      raise messages.first[:body] unless docs.present?
      store!(docs.first)
    end

    def import_many(sourcedb, sourceids)
      docs, messages = fetch(sourcedb, sourceids)
      docs_saved, messages2 = store_many(docs)
      [docs_saved, messages + messages2]
    end
  end
end
