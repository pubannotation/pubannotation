# frozen_string_literal: true

module UploadFilesConcern
  extend ActiveSupport::Concern

  def prepare_upload_files(filepath)
    dirpath = File.join('tmp', 'uploads', File.basename(filepath, ".*"))
    if filepath.end_with?('.tgz')
      unpack_cmd = "mkdir #{dirpath}; tar -xzf #{filepath} -C #{dirpath}"
      unpack_success_p = system(unpack_cmd)
      raise IOError, "Could not unpack the archive file." unless unpack_success_p
    else
      FileUtils.mkdir dirpath
      FileUtils.cp filepath, dirpath
    end
    dirpath
  end

  def remove_upload_files(filepath, dirpath)
    FileUtils.rm_rf(dirpath) unless dirpath.nil?
    File.unlink(filepath)
  end
end
