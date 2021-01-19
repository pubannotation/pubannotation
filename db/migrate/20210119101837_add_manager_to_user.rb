class AddManagerToUser < ActiveRecord::Migration
  def change
    add_column :users, :manager, :boolean, default: false
  end
end
