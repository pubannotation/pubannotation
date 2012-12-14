class AddViewerToAnnset < ActiveRecord::Migration
  def change
    add_column :annsets, :viewer, :string
  end
end
