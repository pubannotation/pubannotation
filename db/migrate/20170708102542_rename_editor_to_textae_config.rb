class RenameEditorToTextaeConfig < ActiveRecord::Migration
  def up
   	change_table :projects do |t|
  		t.remove :editor
  		t.string :textae_config
  	end
  end

  def down
   	change_table :projects do |t|
  		t.remove :textae_config
  		t_string :editor
  	end
  end
end
