class AddNumbersToDoc < ActiveRecord::Migration[4.2]
  def up
  	change_table :docs do |t|
  		t.rename :denotations_count, :denotations_num
  		t.rename :subcatrels_count, :relations_num
  		t.integer :modifications_num, default: 0
  	end
  end

  def down
  	change_table :docs do |t|
  		t.rename :denotations_num, :denotations_count
  		t.rename :relations_num, :subcatrels_count
  		t.remove :modifications_num
  	end
  end
end
