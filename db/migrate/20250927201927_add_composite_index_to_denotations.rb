class AddCompositeIndexToDenotations < ActiveRecord::Migration[8.0]
  def change
    add_index :denotations, [:project_id, :doc_id], name: 'index_denotations_on_project_id_and_doc_id'
  end
end
