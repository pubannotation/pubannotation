class RenameAnnsetsToProjects < ActiveRecord::Migration
  def self.up
    rename_table  :annsets, :projects
    add_index     :projects, :name, :unique => true

    remove_index  :annsets_docs, [:annset_id, :doc_id]
    rename_table  :annsets_docs, :docs_projects
    rename_column :docs_projects, :annset_id, :project_id
    add_index     :docs_projects, [:project_id, :doc_id], :unique => true

    remove_index  :catanns, :annset_id
    rename_column :catanns, :annset_id, :project_id
    add_index     :catanns, :project_id

    remove_index  :insanns, :annset_id
    rename_column :insanns, :annset_id, :project_id
    add_index     :insanns, :project_id

    remove_index  :modanns, :annset_id
    rename_column :modanns, :annset_id, :project_id
    add_index     :modanns, :project_id
    
    rename_column :relanns, :annset_id, :project_id
    remove_index  :relanns, :annset_id
    add_index     :relanns, :project_id
  end

  def self.down
    remove_index :projects, :name
    rename_table :projects, :annsets

    remove_index  :docs_projects, [:project_id, :doc_id]
    rename_table  :docs_projects, :annsets_docs 
    rename_column :annsets_docs, :project_id, :annset_id 
    add_index     :annsets_docs, [:annset_id, :doc_id], :unique => true

    remove_index  :catanns, :project_id
    rename_column :catanns, :project_id, :annset_id
    add_index     :catanns, :annset_id

    remove_index  :insanns, :project_id
    rename_column :insanns, :project_id, :annset_id
    add_index     :insanns, :annset_id
    
    remove_index  :modanns, :project_id
    rename_column :modanns, :project_id, :annset_id
    add_index     :modanns, :annset_id

    remove_index  :relanns, :project_id
    rename_column :relanns, :project_id, :annset_id
    add_index     :relanns, :annset_id
  end
end
