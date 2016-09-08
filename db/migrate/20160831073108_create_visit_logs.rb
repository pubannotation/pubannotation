class CreateVisitLogs < ActiveRecord::Migration
  def change
    create_table :visit_logs do |t|
      t.integer :user_id
      t.integer :project_id
      t.text :url
      t.date :visited_date
    end
  end
end
