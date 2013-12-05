class CreateDocumentations < ActiveRecord::Migration
  def change
    create_table :documentations do |t|
      t.string :title, :null => false
      t.string :body, :null => false
      t.integer :documentation_category_id
    end
    
    add_index :documentations, :documentation_category_id
  end
end
