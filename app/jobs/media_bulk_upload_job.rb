class MediaBulkUploadJob < ApplicationJob
  include UseJobRecordConcern

  queue_as :general

  def self.enqueue(user, uploaded_file)
    zip_path = Rails.root.join('tmp', 'media_bulk_uploads', "#{SecureRandom.uuid}.zip")
    FileUtils.mkdir_p(zip_path.dirname)
    FileUtils.mv(uploaded_file.path, zip_path.to_s)

    perform_later(user, zip_path.to_s)
  end

  def perform(user, zip_path)
    service = MediumBulkUploadService.new(zip_path, user)
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
