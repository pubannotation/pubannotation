class RemoveAbbrevFromAnnotator < ActiveRecord::Migration[4.2]
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
