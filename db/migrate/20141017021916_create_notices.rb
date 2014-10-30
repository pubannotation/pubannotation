class CreateNotices < ActiveRecord::Migration
  def up
    create_table :notices do |t|
      t.integer :project_id
      t.column :created_at, :datetime
    end
    add_index :notices, :project_id
  end

  def down
    drop_table :notices
  end
end
