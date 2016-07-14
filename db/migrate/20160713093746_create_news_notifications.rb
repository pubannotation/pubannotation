class CreateNewsNotifications < ActiveRecord::Migration
  def up
    create_table :news_notifications do |t|
      t.string :title
      t.string :category
      t.string :body
      t.timestamps
    end
  end

  def down
    drop_table :news_notifications
  end
end
