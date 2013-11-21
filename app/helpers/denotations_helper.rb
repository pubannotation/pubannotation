module DenotationsHelper
  def denotations_count_helper(project, options = {})
    if params[:action] == 'spans'
      if project.present?
        options[:doc].denotations.where(:project_id => project.id).within_spans(params[:begin], params[:end]).size
      else
        options[:doc].denotations.within_spans(params[:begin], params[:end]).size
      end
    else      
      if project.present?
        if options[:doc].present?
          Denotation.project_denotations_count(project.id, options[:doc].denotations)
        else
          project.denotations_count
        end
      else
        options[:doc].denotations.size
      end   
    end
  end
end
