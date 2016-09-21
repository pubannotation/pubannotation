class CountersToNumbers < ActiveRecord::Migration
  def up
  	change_table :projects do |t|
  		t.rename :denotations_count, :denotations_num
  		t.rename :relations_count, :relations_num
  		t.integer :modifications_num, :default => 0
  	end
  end

  def down
  	change_table :projects do |t|
  		t.rename :denotations_num, :denotations_count
  		t.rename :relations_num, :relations_count
  		t.remove :modifications_num
  	end
  end
end
