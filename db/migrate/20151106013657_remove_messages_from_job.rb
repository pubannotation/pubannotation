class RemoveMessagesFromJob < ActiveRecord::Migration
  def change
  	remove_column :jobs, :messages
  end
end
