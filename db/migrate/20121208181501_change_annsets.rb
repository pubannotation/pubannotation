class ChangeAnnsets < ActiveRecord::Migration
  def up
  	change_table :annsets do |t|
  	  t.remove :uploader
  	  t.references :user
  	end
  end

  def down
  	change_table :annsets do |t|
  	  t.remove :user
  	  t.string :uploader
  	end
  end
end
