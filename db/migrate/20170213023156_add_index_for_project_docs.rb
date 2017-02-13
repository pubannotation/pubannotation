class AddIndexForProjectDocs < ActiveRecord::Migration
  def up
    add_index :project_docs, :doc_id
    add_index :project_docs, :project_id
    add_index :project_docs, :denotations_num
  end

  def down
    remove_index :project_docs, :doc_id
    remove_index :project_docs, :project_id
    remove_index :project_docs, :denotations_num
  end
end
