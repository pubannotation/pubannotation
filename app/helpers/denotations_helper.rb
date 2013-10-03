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
        if options[:sourceid].present?
          # doc should be present
          options[:doc].same_sourceid_denotations_count
        else
          denotations = options[:doc].present? ? options[:doc].denotations : Denotation
          if project.class == Project
            Denotation.project_denotations_count(project.id, denotations)
          else
            # Sproject
            project.denotations_count
          end
        end
      else
        options[:doc].denotations.size
      end   
    end
  end
end
