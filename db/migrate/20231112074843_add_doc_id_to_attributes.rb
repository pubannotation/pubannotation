class AddDocIdToAttributes < ActiveRecord::Migration[7.0]
  def up
    add_reference :attrivutes, :doc

    execute <<-SQL.squish
      UPDATE attrivutes
      SET doc_id = denotations.doc_id
      FROM denotations
      WHERE attrivutes.subj_id=denotations.id AND attrivutes.subj_type='Denotation'
    SQL

    add_foreign_key :attrivutes, :docs
  end
  def down
    remove_reference :attrivutes, :doc, foreign_key: true
  end
end
