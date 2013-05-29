class RenameColumnRelobjIdToObjIdAndRelobjTypeToObjType < ActiveRecord::Migration
  def up
    remove_index    :relations, :relobj_id
    rename_column   :relations, :relobj_id, :obj_id
    add_index       :relations, :obj_id
    rename_column   :relations, :relobj_type, :obj_type
  end

  def down
    remove_index    :relations, :obj_id
    rename_column   :relations, :obj_id, :relobj_id
    add_index       :relations, :relobj_id
    rename_column   :relations, :obj_type, :relobj_type
  end
end
