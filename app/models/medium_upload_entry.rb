class MediumUploadEntry
  attr_reader :filename, :ext, :sourcedb, :sourceid, :media_type, :content_type

  def initialize(filename:, ext:, sourcedb:, sourceid:, media_type:, content_type:)
    @filename = filename
    @ext = ext
    @sourcedb = sourcedb
    @sourceid = sourceid
    @media_type = media_type
    @content_type = content_type
  end

  def medium_attributes(user:)
    { sourcedb:, sourceid:, media_type:, content_type:, user: }
  end
end
