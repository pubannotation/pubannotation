# frozen_string_literal: true

class DocumentSourcedb
  def self.normalize!(sourcedb, current_user, no_personalize = false)
    if no_personalize
      validate_presence_if_not_personalized!(sourcedb, no_personalize)
      return sourcedb
    end

    separator = Doc::UserSourcedbSeparator
    return separator + current_user.username if sourcedb.blank?
    return sourcedb + separator + current_user.username unless sourcedb.include?(separator)

    parts = sourcedb.split(separator)
    raise ArgumentError, "'#{separator}' is a special character reserved for separation of the username from a personal sourcedb name." unless parts.length == 2

    _, username = parts
    raise ArgumentError, "This document belongs to '#{username}'." unless username == current_user.username

    sourcedb
  end

  def self.validate_presence_if_not_personalized!(sourcedb, no_personalize)
    if no_personalize && sourcedb.blank?
      raise ArgumentError, "For admin, the 'sourcedb' cannot be automatically generated."
    end
  end
end
