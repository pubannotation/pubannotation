class AddCompositeIndexesToAnnotationTables < ActiveRecord::Migration[8.0]
  def change
    add_index :blocks, :doc_id
    add_index :blocks, [:project_id, :doc_id], name: 'index_blocks_on_project_id_and_doc_id'
    add_index :relations, [:project_id, :doc_id], name: 'index_relations_on_project_id_and_doc_id'
    add_index :attrivutes, [:project_id, :doc_id], name: 'index_attrivutes_on_project_id_and_doc_id'
  end
end
