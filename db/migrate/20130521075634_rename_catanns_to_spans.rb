class RenameCatannsToSpans < ActiveRecord::Migration
  def up
    remove_index :catanns, :doc_id
    remove_index :catanns, :project_id
    rename_table  :catanns, :spans
    add_index :spans, :doc_id
    add_index :spans, :project_id
  end

  def down
    remove_index :spans, :doc_id
    remove_index :spans, :project_id
    rename_table  :spans, :catanns
    add_index :catanns, :doc_id
    add_index :catanns, :project_id
  end
end
