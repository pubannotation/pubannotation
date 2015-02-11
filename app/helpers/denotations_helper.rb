module DenotationsHelper
  def denotations_count_helper(project, doc = nil, span = nil)
    if doc.present?
      doc.get_denotations_count(project, span)
    else
      project.denotations_count
    end
  end
end
