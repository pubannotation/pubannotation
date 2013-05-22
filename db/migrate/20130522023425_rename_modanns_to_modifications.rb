class RenameModannsToModifications < ActiveRecord::Migration
  def up
    remove_index  :modanns, :modobj_id
    remove_index  :modanns, :project_id    
    rename_table  :modanns, :modifications
    add_index     :modifications, :modobj_id
    add_index     :modifications, :project_id    
  end

  def down
    remove_index  :modifications, :modobj_id
    remove_index  :modifications, :project_id    
    rename_table  :modifications, :modanns 
    add_index     :modanns, :modobj_id
    add_index     :modanns, :project_id    
  end
end
