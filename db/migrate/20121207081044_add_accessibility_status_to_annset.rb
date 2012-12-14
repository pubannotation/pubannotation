class AddAccessibilityStatusToAnnset < ActiveRecord::Migration
  def change
    add_column :annsets, :accessibility, :integer
    add_column :annsets, :status, :integer
  end
end
