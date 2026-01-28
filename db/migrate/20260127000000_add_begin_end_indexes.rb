class AddBeginEndIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :denotations, [:begin, :end], name: 'index_denotations_on_begin_and_end', algorithm: :concurrently
  end
end
