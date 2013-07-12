module RelationsHelper
  def relations_count_helper(project, doc = nil)
    if project.present?
      if doc.present?
        doc.project_relations_count(project.id)
      else  
        Relation.project_relations_count(project.id, Relation)
      end
    else
      doc.relations_count
    end
  end
end
