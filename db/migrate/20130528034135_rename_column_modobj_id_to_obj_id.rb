class RenameColumnModobjIdToObjId < ActiveRecord::Migration
  def up
    remove_index :modifications, :modobj_id
    rename_column :modifications, :modobj_id, :obj_id
    add_index :modifications, :obj_id
  end

  def down
    remove_index :modifications, :obj_id
    rename_column :modifications, :obj_id, :modobj_id
    add_index :modifications, :modobj_id
  end
end
