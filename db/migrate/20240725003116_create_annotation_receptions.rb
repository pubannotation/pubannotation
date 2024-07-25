class CreateAnnotationReceptions < ActiveRecord::Migration[7.1]
  def change
    create_table :annotation_receptions do |t|
      t.string :uuid, null: false
      t.integer :annotator_id, null: false
      t.integer :project_id, null: false
      t.json :options, default: {}

      t.timestamps
    end
  end
end
