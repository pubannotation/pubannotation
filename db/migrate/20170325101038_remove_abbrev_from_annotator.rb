class RemoveAbbrevFromAnnotator < ActiveRecord::Migration
  def up
   	change_table :annotators do |t|
  		t.remove :abbrev
  	end
  end

  def down
  	change_table :annotators do |t|
      t.string :abbrev
    end
  end
end
