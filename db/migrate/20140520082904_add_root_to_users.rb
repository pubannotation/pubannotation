class AddRootToUsers < ActiveRecord::Migration
  def change
    add_column :users, :root, :boolean, :default => false 
  end
end
