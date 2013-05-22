class RenameRelannsToRelations < ActiveRecord::Migration
  def up
    remove_index  :relanns, :relsub_id
    remove_index  :relanns, :relobj_id
    remove_index  :relanns, :project_id
    rename_table  :relanns, :relations    
    add_index     :relations, :relsub_id
    add_index     :relations, :relobj_id
    add_index     :relations, :project_id
  end

  def down
    remove_index  :relations, :relsub_id
    remove_index  :relations, :relobj_id
    remove_index  :relations, :project_id
    rename_table  :relations, :relanns    
    add_index     :relanns, :relsub_id
    add_index     :relanns, :relobj_id
    add_index     :relanns, :project_id
  end
end
