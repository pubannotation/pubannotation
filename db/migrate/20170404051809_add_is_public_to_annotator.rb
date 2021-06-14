class AddIsPublicToAnnotator < ActiveRecord::Migration[4.2]
  def up
  	change_table :annotators do |t|
  		t.boolean :is_public, default: false
  	end
  end
  def down
  	change_table :annotators do |t|
  		t.remove :is_public
  	end
  end
end
