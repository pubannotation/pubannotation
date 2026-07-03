class MediumUploadEntry
  class ValidationError < StandardError; end

  attr_reader :filename, :ext, :sourcedb, :sourceid, :media_type, :content_type

  def initialize(filename:, ext:, sourcedb:, sourceid:, media_type:, content_type:)
    @filename = filename
    @ext = ext
    @sourcedb = sourcedb
    @sourceid = sourceid
    @media_type = media_type
    @content_type = content_type
  end

  def create_medium(user:, io:)
    medium = Medium.new(sourcedb:, sourceid:, media_type:, content_type:, user:)
    medium.file.attach(io:, filename:, content_type:)
    medium.save
    medium
  end
end
