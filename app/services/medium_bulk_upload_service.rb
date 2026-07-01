class MediumBulkUploadService
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

  def process_entry(entry)
    filename = File.basename(entry.name)
    upload_entry = MediumUploadEntryParser.call(entry)

    Tempfile.create(["media-upload-", upload_entry.ext]) do |tmp|
      input = entry.get_input_stream
      begin
        IO.copy_stream(input, tmp)
        tmp.flush
        tmp.rewind

        medium = upload_entry.create_medium(user: @user, io: tmp)

        if medium.persisted?
          success_result(upload_entry.filename)
        else
          error_result(upload_entry.filename, medium.errors.full_messages.join(', '))
        end
      ensure
        input.close
      end
    end
  rescue MediumUploadEntry::ValidationError => e
    error_result(filename, e.message)
  end
end
