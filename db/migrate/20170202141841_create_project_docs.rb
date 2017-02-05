class CreateProjectDocs < ActiveRecord::Migration
  def up
    create_table :project_docs do |t|
    	t.belongs_to :project
    	t.belongs_to :doc
    	t.integer :denotations_num, default:0
    	t.integer :relations_num, default:0
    	t.integer :modifications_num, default:0
    end

    execute "insert into project_docs (project_id, doc_id) select project_id, doc_id from docs_projects"

    drop_table :docs_projects
  end

  def down
  	change_table :project_docs do |t|
  		t.remove :denotations_num, :relations_num, :modifications_num
  	end

  	rename_table :project_docs, :docs_projects
  end
end
