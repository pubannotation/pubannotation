class AddCanUseMediaToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :can_use_media, :boolean, default: false, null: false
  end
end
