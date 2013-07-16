module RelationsHelper
  def relations_count_helper(project, doc = nil, sourceid = nil)
    if project.present?
      if doc.present?
        if sourceid.present?
          doc.same_sourceid_relations_count
        else
          doc.project_relations_count(project.id)
        end
      else  
        Relation.project_relations_count(project.id, Relation)
      end
    else
      doc.relations_count
    end
  end
end
