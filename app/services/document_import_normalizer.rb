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

      # sourcedb, to be personalized
      if no_personalize
        validate_sourcedb!(hdoc[:sourcedb], no_personalize)
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

    def validate_sourcedb!(sourcedb, no_personalize)
      if no_personalize && sourcedb.blank?
        raise ArgumentError, "For admin, the 'sourcedb' cannot be automatically generated."
      end
    end
  end
end
