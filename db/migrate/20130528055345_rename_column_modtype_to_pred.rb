class RenameColumnModtypeToPred < ActiveRecord::Migration
  def change
    rename_column :modifications, :modtype, :pred
  end
end
