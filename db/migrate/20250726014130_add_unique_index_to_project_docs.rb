class AddUniqueIndexToProjectDocs < ActiveRecord::Migration[8.0]
  INDEX_NAME = "index_project_docs_on_project_id_and_doc_id"

  def up
    if index_exists?(:project_docs, [:project_id, :doc_id], unique: false, name: INDEX_NAME)
      remove_index :project_docs, name: INDEX_NAME
    end
    add_index :project_docs, [:project_id, :doc_id], unique: true, name: "index_project_docs_on_project_id_and_doc_id"
  end

  def down
    remove_index :project_docs, name: "index_project_docs_on_project_id_and_doc_id"
  end
end
