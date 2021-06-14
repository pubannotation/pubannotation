class AddIsBlockToDenotations < ActiveRecord::Migration[4.2]
  def change
    add_column :denotations, :is_block, :boolean, default: false
  end
end
