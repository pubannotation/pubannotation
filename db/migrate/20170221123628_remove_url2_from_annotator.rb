class RemoveUrl2FromAnnotator < ActiveRecord::Migration
  def up
  	change_table :annotators do |t|
  		t.remove :url2, :params2, :method2
  	end
  end

  def down
  	change_table :annotators do |t|
      t.string  :url2
      t.text    :params2
      t.integer :method2
    end
  end
end
