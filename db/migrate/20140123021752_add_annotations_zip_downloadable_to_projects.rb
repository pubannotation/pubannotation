class AddAnnotationsZipDownloadableToProjects < ActiveRecord::Migration
  def change
    add_column :projects, :annotations_zip_downloadable, :boolean, :default => true
  end
end
