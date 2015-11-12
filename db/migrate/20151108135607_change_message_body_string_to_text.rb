class ChangeMessageBodyStringToText < ActiveRecord::Migration
  def up
    change_column :messages, :body, :text
  end

  def down
    change_column :messages, :body, :string
  end
end
