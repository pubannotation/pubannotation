class AddUniqueIndexToProjectDocs < ActiveRecord::Migration[8.0]
  def up
    remove_index :project_docs, name: "index_project_docs_on_project_id_and_doc_id"
    add_index :project_docs, [:project_id, :doc_id], unique: true, name: "index_project_docs_on_project_id_and_doc_id"
  end

  def down
    remove_index :project_docs, name: "index_project_docs_on_project_id_and_doc_id"
    add_index :project_docs, [:project_id, :doc_id], name: "index_project_docs_on_project_id_and_doc_id"
  end
end
