class AddBatchNumToAnnotators < ActiveRecord::Migration
  def up
  	change_table :annotators do |t|
  		t.integer :batch_num, default: 1
  	end
  end
  def down
  	change_table :annotators do |t|
  		t.remove :batch_num
  	end
  end
end
