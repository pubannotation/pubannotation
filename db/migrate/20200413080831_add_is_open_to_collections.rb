class AddIsOpenToCollections < ActiveRecord::Migration[4.2]
  def up
  	change_table :collections do |t|
  		t.boolean :is_open, default: false
  	end
  end
  def down
  	change_table :collections do |t|
  		t.remove :is_open
  	end
  end
end
