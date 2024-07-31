class AddJobReferenceColumnToAnnotationReception < ActiveRecord::Migration[7.1]
  def change
    add_reference :annotation_receptions, :job, foreign_key: true
  end
end
