class MediaBulkUploadJob < ApplicationJob
  queue_as :general

  def self.enqueue(user, uploaded_file)
    zip_path = Rails.root.join('tmp', 'media_bulk_uploads', "#{SecureRandom.uuid}.zip")
    FileUtils.mkdir_p(zip_path.dirname)
    FileUtils.mv(uploaded_file.path, zip_path.to_s)

    perform_later(user, zip_path.to_s)
  end

  def perform(user, zip_path)
    zip_file = OpenStruct.new(path: zip_path)
    service = MediumBulkUploadService.new(zip_file, user)
    service.call
  ensure
    FileUtils.rm_f(zip_path)
  end
end
