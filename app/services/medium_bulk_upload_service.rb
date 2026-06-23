class MediumBulkUploadService
  EXTENSION_TO_MEDIA_TYPE = {
    '.jpg' => [:image, 'image/jpeg'],
    '.jpeg' => [:image, 'image/jpeg'],
    '.png' => [:image, 'image/png'],
    '.gif' => [:image, 'image/gif'],
    '.webp' => [:image, 'image/webp']
  }.freeze

  attr_reader :successes, :errors

  def initialize(zip_file, user)
    @zip_file = zip_file
    @user = user
    @successes = []
    @errors = []
  end

  def call
    Zip::File.open(@zip_file.path) do |zip|
      zip.each do |entry|
        process_entry(entry)
      end
    end
  rescue Zip::Error => e
    raise ArgumentError, "Invalid ZIP file: #{e.message}"
  end

  private

  def process_entry(entry)
    return if entry.directory?

    filename = File.basename(entry.name)
    return if filename.start_with?('.') || entry.name.start_with?('__MACOSX/')

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

    medium = Medium.new(
      sourcedb: sourcedb,
      sourceid: sourceid,
      media_type: media_type,
      content_type: content_type,
      user: @user
    )

    Tempfile.create(["media-upload-", ext]) do |tmp|
      input = entry.get_input_stream
      begin
        IO.copy_stream(input, tmp)
        tmp.flush
        tmp.rewind
        medium.file.attach(io: tmp, filename: filename, content_type: content_type)
        if medium.save
          @successes << filename
        else
          @errors << "#{filename}: #{medium.errors.full_messages.join(', ')}"
        end
      ensure
        input.close
      end
    end
  end
end
