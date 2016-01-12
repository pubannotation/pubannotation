class CreateAnnotations < ActiveRecord::Migration
  def change
    create_table :annotations do |t|
      t.string :type
      t.string :hid
      t.string :pred
      t.string :obj_type
      t.integer :obj_id
      t.string :subj_type
      t.integer :subj_id
      t.integer :doc_id
      t.integer :pred_id
      t.integer :begin
      t.integer :end
    end
    add_index :annotations, :obj_id
    add_index :annotations, :subj_id
    add_index :annotations, :doc_id
  end
end
