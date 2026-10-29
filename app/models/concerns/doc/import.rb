# frozen_string_literal: true

module Doc::Import
  extend ActiveSupport::Concern

  class_methods do
    def parse_filename(_filename)
      parts = _filename.split('-')
      raise ArgumentError, "The filename of a txt file has to be in the form of 'sourcedb-sourceid': #{_filename}" unless parts.length > 1
      sourceid = parts.pop
      sourcedb = parts.join('-')
      [sourcedb, sourceid]
    end

    def hdoc_normalize!(hdoc, current_user, no_personalize = false)
      raise SecurityError, "You have to be logged in to create a document." unless current_user.present?

      # body = text
      hdoc[:body] ||= hdoc[:text] || raise(ArgumentError, "Text is missing.")
      hdoc.delete(:text) if hdoc[:text].present?

      # sourcedb, to be personalized
      if no_personalize
        raise ArgumentError, "For admin, the 'sourcedb' cannot be automatically generated." unless hdoc[:sourcedb].present?
      else
        # personalize the sourcedb unless no_personalize
        if hdoc[:sourcedb].present?
          if hdoc[:sourcedb].include?(Doc::UserSourcedbSeparator)
            parts = hdoc[:sourcedb].split(Doc::UserSourcedbSeparator)
            raise ArgumentError, "'#{Doc::UserSourcedbSeparator}' is a special character reserved for separation of the username from a personal sourcedb name." unless parts.length == 2
            sourcedb, username = parts
            raise ArgumentError, "This document belongs to '#{username}'." unless username == current_user.username
          else
            hdoc[:sourcedb] += Doc::UserSourcedbSeparator + current_user.username
          end
        else
          hdoc[:sourcedb] = Doc::UserSourcedbSeparator + current_user.username
        end
      end

      # sourceid control
      unless hdoc[:sourceid].present?
        last_id = Doc.where(sourcedb: hdoc[:sourcedb]).pluck(:sourceid).max_by{|i| i.to_i}
        hdoc[:sourceid] = last_id.nil? ? '1' : last_id.next
      end

      hdoc
    end

    def hdoc_valid?(hdoc)
      return false unless hdoc[:text].present?
      return false unless hdoc[:sourcedb].present?
      return false unless hdoc[:sourceid].present?
      true
    end

    # Returns [documents, messages].
    def sequence_docs(sourcedb, sourceids)
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
      docs, messages = sequence_docs(sourcedb, [sourceid])
      raise messages.first[:body] unless docs.present?
      store_hdoc!(docs.first)
    end

    def sequence_and_store_docs(sourcedb, sourceids)
      docs, messages = sequence_docs(sourcedb, sourceids)
      docs_saved, messages2 = store_hdocs(docs)
      [docs_saved, messages + messages2]
    end
  end
end
