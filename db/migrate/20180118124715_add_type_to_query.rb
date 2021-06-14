class AddTypeToQuery < ActiveRecord::Migration[4.2]
  def up
  	change_table :queries do |t|
  		t.integer :category, default:2
  	end
  end

  def down
  	change_table :queries do |t|
  		t.remove :category
  	end
  end
end
