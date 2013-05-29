class RenameColumnInstypeToPred < ActiveRecord::Migration
  def change
    rename_column :instances, :instype, :pred
  end
end
