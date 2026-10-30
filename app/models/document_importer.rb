# frozen_string_literal: true

class DocumentImporter
  class << self
    def store_hdoc!(hdoc)
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

    def store_hdoc(hdoc)
      begin
        store_hdoc!(hdoc)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
        if e.message.include?("already been taken") || e.message.include?("duplicate") || e.message.include?("unique")
          # Document was created by another job (race condition) - find and return it
          Doc.find_by(sourcedb: hdoc[:sourcedb], sourceid: hdoc[:sourceid])
        else
          raise e
        end
      end
    end

    def store_hdocs(hdocs)
      docs_saved = []
      messages = []

      hdocs.each do |hdoc|
        doc = store_hdoc(hdoc)
        docs_saved << doc if doc  # Only add if doc was created/found
      rescue => e
        messages << {sourcedb:hdoc[:sourcedb], sourceid:[hdoc[:sourceid]], body:e.message}
      end

      [docs_saved, messages]
    end

    def sequence_and_store_doc!(sourcedb, sourceid)
      docs, messages = DocumentFetcher.fetch(sourcedb, [sourceid])
      raise messages.first[:body] unless docs.present?
      store_hdoc!(docs.first)
    end

    def sequence_and_store_docs(sourcedb, sourceids)
      docs, messages = DocumentFetcher.fetch(sourcedb, sourceids)
      docs_saved, messages2 = store_hdocs(docs)
      [docs_saved, messages + messages2]
    end
  end
end
