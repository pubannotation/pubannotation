class AddIndexsToDocs < ActiveRecord::Migration
  def change
  	add_index :docs, :sourcedb
  	add_index :docs, :serial
  end
end
