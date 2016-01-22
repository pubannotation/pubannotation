class MigrateModifications < ActiveRecord::Migration
  def up
    # Create pred master table
    modifications = ActiveRecord::Base.connection.exec_query('SELECT * FROM Modifications').to_hash
    modifications.collect{|d| d["pred"]}.uniq.each do |pred_name|
      Pred.create(name: pred_name)
    end

    modifications.each do |modification|
      annotation = Annotation.create(
        {
          hid: modification["hid"],
          pred_id: Pred.find_by_name( modification["pred"] ),
          obj_type: modification["obj_type"],
          obj_id: modification["obj_id"],
          type: 'Modification'
        }
      )
      if modification["project_id"].present?
        if Project.where(id: modification["project_id"]).present?
          AnnotationsProject.create(annotation_id: modification["id"], project_id: modification["project_id"])
        end
      end
    end
  end

  def down
    Annotation.delete_all("type = 'Modification'")
  end
end
