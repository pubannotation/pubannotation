class MediaBulkUploadJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(user, zip_path)
    zip_file = OpenStruct.new(path: zip_path)
    service = MediumBulkUploadService.new(zip_file, user)
    service.call

    prepare_progress_record(service.successes.size + service.errors.size)

    service.successes.each do |filename|
      increment_progress
    end

    service.errors.each do |error|
      @job&.add_message(sourcedb: '*', sourceid: '*', body: error)
      increment_progress
    end
  ensure
    FileUtils.rm_f(zip_path)
  end

  def job_name
    'Media Bulk Upload'
  end
end
