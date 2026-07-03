class MediumUploadEntryParser
  EXTENSION_TO_MEDIA_TYPE = {
    '.jpg' => [:image, 'image/jpeg'],
    '.jpeg' => [:image, 'image/jpeg'],
    '.png' => [:image, 'image/png'],
    '.gif' => [:image, 'image/gif'],
    '.webp' => [:image, 'image/webp']
  }.freeze

  def self.call(entry)
    new(entry).call
  end

  def initialize(entry)
    @entry = entry
  end

  def call
    filename = File.basename(entry.name)
    ext = File.extname(filename).downcase

    raise MediumUploadEntry::ValidationError, "#{filename}: no extension, skipped." if ext.blank?

    unless EXTENSION_TO_MEDIA_TYPE.key?(ext)
      raise MediumUploadEntry::ValidationError, "#{filename}: unsupported extension '#{ext}', skipped."
    end

    basename = File.basename(filename, ext)

    unless basename.match?(/\A[^\s-]+-[^\s-]+\z/)
      raise MediumUploadEntry::ValidationError,
            "#{filename}: filename must be in 'sourcedb-sourceid#{ext}' format (one hyphen, no spaces), skipped."
    end

    sourcedb, sourceid = basename.split('-', 2)
    media_type, content_type = EXTENSION_TO_MEDIA_TYPE.fetch(ext)

    MediumUploadEntry.new(
      filename:,
      ext:,
      sourcedb:,
      sourceid:,
      media_type:,
      content_type:
    )
  end

  private

  attr_reader :entry
end
