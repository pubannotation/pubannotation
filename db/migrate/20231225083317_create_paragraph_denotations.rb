class CreateParagraphDenotations < ActiveRecord::Migration[7.0]
  def change
    create_table :paragraph_denotations do |t|
      t.references :division, null: false, foreign_key: true
      t.references :denotation, null: false, foreign_key: true

      t.timestamps
    end
  end
end
