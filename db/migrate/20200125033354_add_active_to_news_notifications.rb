class AddActiveToNewsNotifications < ActiveRecord::Migration
  def change
    add_column :news_notifications, :active, :boolean, default: false
  end
end
