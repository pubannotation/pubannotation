class ChangeAnnotatorAndProjectReferencesInAnnotationReceptions < ActiveRecord::Migration[7.1]
  def change
    remove_column :annotation_receptions, :annotator_id, :integer
    remove_column :annotation_receptions, :project_id, :integer

    add_reference :annotation_receptions, :annotator, foreign_key: true
    add_reference :annotation_receptions, :project, foreign_key: true
  end
end
