module DenotationsHelper
  def denotations_count_helper(project, doc = nil, sourceid = nil)
    if project.present?
      if sourceid.present?
        # doc should be present
        doc.same_sourceid_denotations_count
      else
        denotations = doc.present? ? doc.denotations : Denotation
        Denotation.project_denotations_count(project.id, denotations)
      end
    else
      doc.denotations.size
    end   
  end
end
