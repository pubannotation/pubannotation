MediumUploadEntry = Data.define(:filename, :ext, :sourcedb, :sourceid, :media_type, :content_type) do
  def medium_attributes(user:)
    { sourcedb:, sourceid:, media_type:, content_type:, user: }
  end
end
