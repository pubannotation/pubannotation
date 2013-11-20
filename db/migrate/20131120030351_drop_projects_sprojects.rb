class DropProjectsSprojects < ActiveRecord::Migration
  def change
    drop_table :projects_sprojects
  end
end
