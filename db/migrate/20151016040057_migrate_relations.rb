class MigrateRelations < ActiveRecord::Migration
  def up
    # Create pred master table
    relations = ActiveRecord::Base.connection.exec_query('SELECT * FROM Relations').to_hash
    relations.collect{|r| r['pred']}.uniq.each do |pred_name|
      Pred.create(name: pred_name)
    end

    relations.each do |relation|
      annotation = Annotation.create(
        {
          hid: relation['hid'],
          subj_id: relation['subj_id'],
          subj_type: relation['subj_type'],
          pred_id: Pred.find_by_name(relation['pred']).id,
          obj_id: relation['obj_id'],
          obj_type: relation['obj_type'],
          type: 'Relation'
        }
      )
      if relation['project_id'].present?
        if Project.where(id: relation['project_id']).present?
          AnnotationsProject.create(annotation_id: relation['id'], project_id: relation['project_id'])
        end
      end
    end
  end

  def down
    Annotation.delete_all("type = 'Relation'")
  end
end
