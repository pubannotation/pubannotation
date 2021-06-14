class CreateEvaluations < ActiveRecord::Migration[4.2]
  def change
    create_table :evaluations do |t|
      t.references :study_project
      t.references :reference_project
      t.references :evaluator
      t.string :note
      t.text :result
      t.references :user
      t.boolean :is_public, default: false

      t.timestamps
    end
    add_index :evaluations, :study_project_id
    add_index :evaluations, :reference_project_id
    add_index :evaluations, :evaluator_id
    add_index :evaluations, :user_id
  end
end
