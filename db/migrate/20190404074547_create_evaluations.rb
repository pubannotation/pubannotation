class CreateEvaluations < ActiveRecord::Migration
  def change
    create_table :evaluations do |t|
      t.references :study_project
      t.references :reference_project
      t.references :evaluator
      t.text :result
      t.boolean :is_public, default: false

      t.timestamps
    end
    add_index :evaluations, :study_project_id
    add_index :evaluations, :reference_project_id
    add_index :evaluations, :evaluator_id
  end
end
