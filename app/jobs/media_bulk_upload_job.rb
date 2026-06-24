class MediaBulkUploadJob < ApplicationJob
  queue_as :general

  def perform(user, zip_path)
    zip_file = OpenStruct.new(path: zip_path)
    service = MediumBulkUploadService.new(zip_file, user)
    service.call
  ensure
    FileUtils.rm_f(zip_path)
  end
end
