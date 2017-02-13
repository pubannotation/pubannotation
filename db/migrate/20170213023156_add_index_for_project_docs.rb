class AddIndexForProjectDocs < ActiveRecord::Migration
  def up
    add_index :docs, :denotations_num
    rename_index :docs, :index_docs_on_projects_count, :index_docs_on_projects_num
    add_index :project_docs, :doc_id
    add_index :project_docs, :project_id
    add_index :project_docs, :denotations_num
  end

  def down
    remove_index :docs, :denotations_num
    rename_index :docs, :index_docs_on_projects_num, :index_docs_on_projects_count
    remove_index :project_docs, :doc_id
    remove_index :project_docs, :project_id
    remove_index :project_docs, :denotations_num
  end
end
