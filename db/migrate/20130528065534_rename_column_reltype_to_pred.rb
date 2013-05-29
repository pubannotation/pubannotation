class RenameColumnReltypeToPred < ActiveRecord::Migration
  def change
    rename_column :relations, :reltype, :pred
  end
end
