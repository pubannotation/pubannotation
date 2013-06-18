class RenameInsannsToInstances < ActiveRecord::Migration
  def up
    remove_index  :insanns, :insobj_id
    remove_index  :insanns, :project_id
    rename_table  :insanns, :instances

    Modification.where(:modobj_type => 'Insann').update_all(:modobj_type =>'Instance')

    add_index     :instances, :insobj_id
    add_index     :instances, :project_id
  end

  def down
    remove_index  :instances, :insobj_id
    remove_index  :instances, :project_id
    rename_table  :instances, :insanns
    add_index     :insanns, :insobj_id
    add_index     :insanns, :project_id
  end
end
