class ChangeDocumentationsBodyStringToText < ActiveRecord::Migration
  def up
    change_column :documentations, :body, :text, :limit => nil
  end

  def down
    change_column :documentations, :body, :string
  end
end
