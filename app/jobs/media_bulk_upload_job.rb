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

    prepare_progress_record(service.total_count)

    service.call do |result|
      if result.status == :error
        @job&.add_message(sourcedb: '*', sourceid: '*', body: result.message)
      end

      increment_progress
      check_suspend_flag

    end
  ensure
    FileUtils.rm_f(zip_path)
  end

  def job_name
    'Media Bulk Upload'
  end
end
