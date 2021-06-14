class AddActiveToNewsNotifications < ActiveRecord::Migration[4.2]
  def change
    add_column :news_notifications, :active, :boolean, default: false
  end
end
