module DenotationsHelper
  def denotations_count_helper(project, doc = nil)
    if project.present?
      denotations = doc.present? ? doc.denotations : Denotation
      Denotation.project_denotations_count(project.id, denotations)
    else
      doc.denotations.size
    end   
  end
end
