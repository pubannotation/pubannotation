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

  def down
    remove_index :denotations, :doc_id
    remove_index :denotations, :project_id

    Relation.where(:subj_type => 'Denotation').update_all(:subj_type =>'Span')
    Relation.where(:obj_type => 'Denotation').update_all(:obj_type =>'Span')

    rename_column :denotations, :obj, :category
    rename_table  :denotations, :spans

    add_index :spans, :doc_id
    add_index :spans, :project_id
  end
end
