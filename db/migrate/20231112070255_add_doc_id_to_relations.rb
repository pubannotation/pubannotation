class AddDocIdToRelations < ActiveRecord::Migration[7.0]
  def up
    add_reference :relations, :doc

    execute <<-SQL.squish
      UPDATE relations
      SET doc_id = denotations.doc_id
      FROM denotations
      WHERE relations.subj_id=denotations.id AND relations.subj_type='Denotation'
    SQL

    add_foreign_key :relations, :docs
  end
  def down
    remove_reference :relations, :doc, foreign_key: true
  end
end
