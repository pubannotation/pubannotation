class ChangeMessagesItemToSourcedbSourceidDivid < ActiveRecord::Migration
  def up
  	change_table :messages do |t|
  		t.string :sourcedb
  		t.string :sourceid
  		t.integer :divid
  		t.remove :item
  	end
  end

  def down
  	change_table :messages do |t|
  		t.remove :sourcedb
  		t.remove :sourceid
  		t.remove :divid
  		t.string :item
  	end
  end
end
