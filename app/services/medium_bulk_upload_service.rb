class MediumBulkUploadService
  def initialize(zip_path, user)
    @zip_path = zip_path
    @user = user
    @successes = []
    @errors = []
  end

  def success_count
    @successes.size
  end

  def error_messages
    @errors
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

  def process_entry(entry)
    return if skippable_entry?(entry)

    upload_entry = MediumUploadEntryParser.call(entry)

    Tempfile.create(["media-upload-", upload_entry.ext]) do |tmp|
      input = entry.get_input_stream
      begin
        IO.copy_stream(input, tmp)
        tmp.flush
        tmp.rewind

        medium = upload_entry.create_medium(user: @user, io: tmp)

        if medium.persisted?
          @successes << upload_entry.filename
        else
          @errors << "#{upload_entry.filename}: #{medium.errors.full_messages.join(', ')}"
        end
      ensure
        input.close
      end
    end
  rescue MediumUploadEntry::ValidationError => e
    @errors << e.message
  end
end
