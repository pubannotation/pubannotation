class AddFlagToProjectDocs < ActiveRecord::Migration[7.0]
  def change
    add_column :project_docs, :flag, :boolean, default: false
  end
end
