class AddForeignKeysToAnnotationReceptions < ActiveRecord::Migration[7.1]
  def change
    add_foreign_key :annotation_receptions, :annotators
    add_foreign_key :annotation_receptions, :projects
  end
end
