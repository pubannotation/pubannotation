class AddUsernameIndexToUsers < ActiveRecord::Migration
  def change
    change_column :users, :username, :text, :null => false, :default => ""
    add_index :users, :username, :unique => true
  end
end
