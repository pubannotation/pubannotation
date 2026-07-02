class MediumBulkUploadService
  EXTENSION_TO_MEDIA_TYPE = {
    '.jpg' => [:image, 'image/jpeg'],
    '.jpeg' => [:image, 'image/jpeg'],
    '.png' => [:image, 'image/png'],
    '.gif' => [:image, 'image/gif'],
    '.webp' => [:image, 'image/webp']
  }.freeze

  def initialize(zip_path, user)
    @zip_path = zip_path
    @user = user
    @successes = []
    @errors = []
  end

  def call
    Zip::File.open(@zip_path) do |zip|
      zip.each do |entry|
        process_entry(entry)
      end
    end
  rescue Zip::Error => e
    raise ArgumentError, "Invalid ZIP file: #{e.message}"
  end

  private

  def skippable_entry?(entry)
    filename = File.basename(entry.name)

    entry.directory? ||
      filename.start_with?('.') ||
      entry.name.start_with?('__MACOSX/')
  end

  def validate_entry(entry)
    filename = File.basename(entry.name)
    ext = File.extname(filename).downcase

    unless ext.present?
      @errors << "#{filename}: no extension, skipped."
      return
    end

    unless EXTENSION_TO_MEDIA_TYPE.key?(ext)
      @errors << "#{filename}: unsupported extension '#{ext}', skipped."
      return
    end

    basename = File.basename(filename, ext)

    unless basename.match?(/\A[^\s-]+-[^\s-]+\z/)
      @errors << "#{filename}: filename must be in 'sourcedb-sourceid#{ext}' format (one hyphen, no spaces), skipped."
      return
    end

    sourcedb, sourceid = basename.split('-', 2)
    media_type, content_type = EXTENSION_TO_MEDIA_TYPE[ext]

    MediumUploadEntry.new(filename:, ext:, sourcedb:, sourceid:, media_type:, content_type:)
  end

  def process_entry(entry)
    return if skippable_entry?(entry)

    upload_entry = validate_entry(entry)
    return unless upload_entry

    Tempfile.create(["media-upload-", upload_entry.ext]) do |tmp|
      input = entry.get_input_stream
      begin
        IO.copy_stream(input, tmp)
        tmp.flush
        tmp.rewind

        medium = Medium.create_with_file(upload_entry, user: @user, io: tmp)

        if medium.persisted?
          @successes << upload_entry.filename
        else
          @errors << "#{upload_entry.filename}: #{medium.errors.full_messages.join(', ')}"
        end
      ensure
        input.close
      end
    end
  end
end
