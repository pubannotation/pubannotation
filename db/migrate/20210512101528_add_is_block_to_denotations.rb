class AddIsBlockToDenotations < ActiveRecord::Migration
  def change
    add_column :denotations, :is_block, :boolean, default: false
  end
end
