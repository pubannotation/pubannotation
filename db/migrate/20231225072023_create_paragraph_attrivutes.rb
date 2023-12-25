class CreateParagraphAttrivutes < ActiveRecord::Migration[7.0]
  def change
    create_table :paragraph_attrivutes do |t|
      t.references :division, null: false, foreign_key: true
      t.references :attrivute, null: false, foreign_key: true

      t.timestamps
    end
  end
end
