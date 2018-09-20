class AddColumnUsers < ActiveRecord::Migration
  def up
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_column :users, :name, :string
    add_column :users, :token, :string
  end

  def down
  end
end
