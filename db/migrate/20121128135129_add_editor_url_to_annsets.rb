class AddEditorUrlToAnnsets < ActiveRecord::Migration
  def change
  	add_column :annsets, :editor, :string
  end
end
