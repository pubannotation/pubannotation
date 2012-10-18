class AddMetaInfoToAnnsets < ActiveRecord::Migration
  def change
    rename_column :annsets, :annotator, :author
    add_column :annsets, :license, :string
    add_column :annsets, :uploader, :string
    add_column :annsets, :reference, :string
  end
end
