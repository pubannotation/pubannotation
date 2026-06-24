class MediaBulkUploadJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def perform(user, zip_path)
    zip_file = OpenStruct.new(path: zip_path)
    service = MediumBulkUploadService.new(zip_file, user)
    service.call

    prepare_progress_record(service.success_count + service.error_messages.size)

    service.success_count.times { increment_progress }

    service.error_messages.each do |error|
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
