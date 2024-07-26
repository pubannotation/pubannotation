class CreateAnnotationReceptions < ActiveRecord::Migration[7.1]
  def change
    create_table :annotation_receptions do |t|
      t.string :uuid, null: false
      t.json :options, default: {}
      t.references :annotator, foreign_key: true
      t.references :project, foreign_key: true

      t.timestamps
    end
  end
end
