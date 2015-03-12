class AddDeltaToDocs < ActiveRecord::Migration
  def change
    add_column :docs, :delta, :boolean, default: true, null: false
  end
end
