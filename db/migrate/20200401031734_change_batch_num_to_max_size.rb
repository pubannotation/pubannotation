class ChangeBatchNumToMaxSize < ActiveRecord::Migration[4.2]
  def up
   	change_table :annotators do |t|
  		t.integer :max_text_size
  		t.boolean :async_protocol, default: false
  	end

  	Annotator.where('batch_num > 1').update_all ["async_protocol = ?", true]

   	change_table :annotators do |t|
  		t.remove :batch_num
  	end
  end

  def down
   	change_table :annotators do |t|
  		t.integer :batch_num, default: 1
  	end

  	Annotator.where('async_protocol': true).update_all ["batch_num = ?", 100]

   	change_table :annotators do |t|
  		t.remove :max_text_size
  		t.remove :async_protocol
  	end
  end
end
