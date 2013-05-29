class RenameColumnModobjTypeToObjType < ActiveRecord::Migration
  def change
    rename_column :modifications, :modobj_type, :obj_type
  end
end
