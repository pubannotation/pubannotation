class DeltaToFlag < ActiveRecord::Migration[4.2]
  def up
  	change_table :docs do |t|
  		t.remove :delta
      t.boolean :flag, default: false, null: false
  	end
  end

  def down
  	change_table :docs do |t|
  		t.remove :flag
  		t.boolean :delta, default: true, null: false
  	end
  end
end
