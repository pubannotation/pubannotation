class AddDataToMessage < ActiveRecord::Migration[4.2]
  def change
    add_column :messages, :data, :text
  end
end
