class RenameColumnInsobjIdToObjId < ActiveRecord::Migration
  def self.up
    remove_index :instances, :insobj_id
    rename_column :instances, :insobj_id, :obj_id
    add_index :instances, :obj_id
  end

  def self.down
    remove_index :instances, :obj_id
    rename_column :instances, :obj_id, :insobj_id
    add_index :instances, :insobj_id
  end
end
