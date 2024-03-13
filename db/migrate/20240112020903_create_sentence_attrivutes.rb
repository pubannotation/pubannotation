class CreateSentenceAttrivutes < ActiveRecord::Migration[7.0]
  def change
    create_table :sentence_attrivutes do |t|
      t.references :block, null: false, foreign_key: true
      t.references :attrivute, null: false, foreign_key: true

      t.timestamps
    end
  end
end
