class RenameCatannsToSpans < ActiveRecord::Migration
  def up
    remove_index :catanns, :doc_id
    remove_index :catanns, :project_id

    rename_table :catanns, :spans

    Relann.where(:relsub_type => 'Catann').update_all(:relsub_type =>'Span')
    Relann.where(:relobj_type => 'Catann').update_all(:relobj_type =>'Span')

    add_index :spans, :doc_id
    add_index :spans, :project_id
  end

  def down
    remove_index :spans, :doc_id
    remove_index :spans, :project_id

    Relann.where(:relsub_type => 'Span').update_all(:relsub_type =>'Catann')
    Relann.where(:relobj_type => 'Span').update_all(:relobj_type =>'Catann')

    rename_table  :spans, :catanns

    add_index :catanns, :doc_id
    add_index :catanns, :project_id
  end
end
