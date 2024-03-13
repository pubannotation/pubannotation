class CreateSentenceDenotations < ActiveRecord::Migration[7.0]
  def change
    create_table :sentence_denotations do |t|
      t.references :block, null: false, foreign_key: true
      t.references :denotation, null: false, foreign_key: true

      t.timestamps
    end
  end
end
