class AddPmdocsCountAndPmcdocsCountAndDenotationsCountAndRelationsCountToProjects < ActiveRecord::Migration
  def up
    add_column :projects, :pmdocs_count, :integer, :default => 0
    add_column :projects, :pmcdocs_count, :integer, :default => 0
    add_column :projects, :denotations_count, :integer, :default => 0
    add_column :projects, :relations_count, :integer, :default => 0

    # set current count for each counter column
    Project.unscoped.each do |project|
      if project.type == 'Sproject'
        pmdocs_count = project.pmdocs.length
        pmcdocs_count = project.pmcdocs.length
        denotations_count = Denotation.projects_denotations(project.project_ids).length
        relations_count = Relation.projects_relations(project.project_ids).length
      else  
        pmdocs_count = project.docs.pmdocs.length
        pmcdocs_count = project.docs.pmcdocs.length
        denotations_count = project.denotations.length
        relations_count = project.relations.length
      end
      Project.unscoped.update_counters project.id,
        :pmdocs_count => pmdocs_count,
        :pmcdocs_count => pmcdocs_count,
        :denotations_count => denotations_count,
        :relations_count => relations_count
    end
  end

  def down
    remove_column :projects, :pmdocs_count
    remove_column :projects, :pmcdocs_count
    remove_column :projects, :denotations_count
    remove_column :projects, :relations_count
  end
end
