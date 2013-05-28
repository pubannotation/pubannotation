class RenameColumnInsobjIdToObjId < ActiveRecord::Migration
  def change
    rename_column :instances, :insobj_id, :obj_id
  end
end
