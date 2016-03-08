class MigrateDenotations < ActiveRecord::Migration
  def up
    # Create obj master table
    denotations = ActiveRecord::Base.connection.exec_query('SELECT * FROM Denotations').to_hash
    denotations.collect{|d| d['obj']}.uniq.each do |obj_name|
      Obj.create(name: obj_name)
    end

    denotations.each do |denotation|
      annotation = Annotation.create(
        {
          type: 'Denotation',
          hid: denotation['hid'],
          pred: nil,
          obj_id: Obj.find_by_name(denotation['obj']).id,
          obj_type: 'Obj',
          begin: denotation['begin'],
          end: denotation['end']
        }
      )
      if denotation['project_id'].present?
        if Project.where(id: denotation['project_id']).present?
          AnnotationsProject.create(annotation_id: denotation['id'], project_id: denotation['project_id'])
        end
      end
    end
  end

  def down
    Annotation.delete_all("type = 'Denotation'")
    AnnotationsProject.delete_all('id > 0')
  end
end
