class RenameSpansToDenotations < ActiveRecord::Migration
  def up
    remove_index :spans, :doc_id
    remove_index :spans, :project_id

    rename_table  :spans, :denotations
    rename_column :denotations, :category, :obj

    Relation.where(:subj_type => 'Span').update_all(:subj_type =>'Denotation')
    Relation.where(:obj_type => 'Span').update_all(:obj_type =>'Denotation')

    add_index :denotations, :doc_id
    add_index :denotations, :project_id
  end
end
