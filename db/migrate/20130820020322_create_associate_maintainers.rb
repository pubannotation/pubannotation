class CreateAssociateMaintainers < ActiveRecord::Migration
  def change
    create_table :associate_maintainers do |t|
      t.integer :user_id
      t.integer :project_id
      
      t.timestamps
    end
    add_index :associate_maintainers, :user_id    
    add_index :associate_maintainers, :project_id    
  end
end
