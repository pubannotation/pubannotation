class AddMessageToNotice < ActiveRecord::Migration
  def change
  	add_column :notices, :message, :string
  end
end
