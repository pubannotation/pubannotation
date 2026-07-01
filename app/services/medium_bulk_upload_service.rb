class MediumBulkUploadService
  EXTENSION_TO_MEDIA_TYPE = {
    '.jpg' => [:image, 'image/jpeg'],
    '.jpeg' => [:image, 'image/jpeg'],
    '.png' => [:image, 'image/png'],
    '.gif' => [:image, 'image/gif'],
    '.webp' => [:image, 'image/webp']
  }.freeze

  Result = Data.define(:filename, :status, :message)

  def initialize(zip_path, user)
    @zip_path = zip_path
    @user = user
  end

  def total_count
    @total_count ||= Zip::File.open(@zip_path) do |zip|
      zip.count { |entry| !skippable_entry?(entry) }
    end
  rescue Zip::Error => e
    raise ArgumentError, "Invalid ZIP file: #{e.message}"
  end

  def call
    Zip::File.open(@zip_path) do |zip|
      zip.each do |entry|
        next if skippable_entry?(entry)
        result = process_entry(entry)
        yield result if block_given?
      end
    end
  rescue Zip::Error => e
    raise ArgumentError, "Invalid ZIP file: #{e.message}"
  end

  private

  def success_result(filename)
    Result.new(filename:, status: :success, message: nil)
  end

  def error_result(filename, message)
    Result.new(filename:, status: :error, message:)
  end

  def skippable_entry?(entry)
    filename = File.basename(entry.name)

    entry.directory? ||
      filename.start_with?('.') ||
      entry.name.start_with?('__MACOSX/')
  end

  def validate_entry(entry)
    filename = File.basename(entry.name)
    ext = File.extname(filename).downcase

    raise "#{filename}: no extension, skipped." unless ext.present?
    raise "#{filename}: unsupported extension '#{ext}', skipped." unless EXTENSION_TO_MEDIA_TYPE.key?(ext)

    basename = File.basename(filename, ext)
    unless basename.match?(/\A[^\s-]+-[^\s-]+\z/)
      raise "#{filename}: filename must be in 'sourcedb-sourceid#{ext}' format (one hyphen, no spaces), skipped."
    end

    sourcedb, sourceid = basename.split('-', 2)
    media_type, content_type = EXTENSION_TO_MEDIA_TYPE[ext]

    { filename:, ext:, sourcedb:, sourceid:, media_type:, content_type: }
  end

  def process_entry(entry)
    filename = File.basename(entry.name)
    attributes = validate_entry(entry)

    Tempfile.create(["media-upload-", attributes[:ext]]) do |tmp|
      input = entry.get_input_stream
      begin
        IO.copy_stream(input, tmp)
        tmp.flush
        tmp.rewind

        medium = Medium.create_with_file(
          {
            sourcedb: attributes[:sourcedb],
            sourceid: attributes[:sourceid],
            media_type: attributes[:media_type],
            content_type: attributes[:content_type],
            user: @user
          },
          io: tmp,
          filename: attributes[:filename],
          content_type: attributes[:content_type]
        )

        if medium.persisted?
          success_result(attributes[:filename])
        else
          error_result(attributes[:filename], medium.errors.full_messages.join(', '))
        end
      ensure
        input.close
      end
    end
  rescue => e
    error_result(filename, e.message)
  end
end
