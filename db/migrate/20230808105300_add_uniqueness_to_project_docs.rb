class AddUniquenessToProjectDocs < ActiveRecord::Migration[7.0]
  def change
    change_table :project_docs do |t|
      t.index [:project_id, :doc_id], unique: true
    end
  end
end
