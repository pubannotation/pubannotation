class AddItemToMessage < ActiveRecord::Migration
  def change
    add_column :messages, :item, :string
  end
end
