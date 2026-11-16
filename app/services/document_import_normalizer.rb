# frozen_string_literal: true

class DocumentImportNormalizer
  class << self
    def parse_filename(_filename)
      parts = _filename.split('-')
      raise ArgumentError, "The filename of a txt file has to be in the form of 'sourcedb-sourceid': #{_filename}" unless parts.length > 1
      sourceid = parts.pop
      sourcedb = parts.join('-')
      [sourcedb, sourceid]
    end

    def normalize!(hdoc, current_user, no_personalize = false)
      raise SecurityError, "You have to be logged in to create a document." unless current_user.present?

      # body = text
      hdoc[:body] ||= hdoc[:text] || raise(ArgumentError, "Text is missing.")
      hdoc.delete(:text) if hdoc[:text].present?

      hdoc[:sourcedb] = DocumentSourcedb.normalize!(hdoc[:sourcedb], current_user, no_personalize)

      # sourceid control
      unless hdoc[:sourceid].present?
        last_id = Doc.where(sourcedb: hdoc[:sourcedb]).pluck(:sourceid).max_by{|i| i.to_i}
        hdoc[:sourceid] = last_id.nil? ? '1' : last_id.next
      end

      hdoc
    end

  end
end
