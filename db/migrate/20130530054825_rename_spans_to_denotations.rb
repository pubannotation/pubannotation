class RenameSpansToDenotations < ActiveRecord::Migration
  def change
    rename_table  :spans, :denotations
    rename_column :denotations, :category, :obj
  end
end
