class CreateDivs < ActiveRecord::Migration
  def change
    create_table :divs do |t|
      t.integer :doc_id
      t.integer :begin
      t.integer :end
      t.string :section
      t.integer :serial
    end
  end
end
