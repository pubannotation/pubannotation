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
          if params[:controller] == 'projects' && options[:doc].sourcedb == 'PMC'
            project.denotations.project_pmcdoc_denotations(options[:sourceid]).count
          else  
            Denotation.project_denotations_count(project.id, options[:doc].denotations)
          end
        else
          project.denotations_count
        end
      else
        options[:doc].denotations.size
      end   
    end
  end
  
  def spans_link_helper(denotation)
    if params[:controller] == 'pmdocs' || params[:pmdoc_id].present?
      params[:id] ||= params[:pmdoc_id] 
      link_to "#{denotation[:span][:begin]}-#{ denotation[:span][:end]}", spans_pmdoc_path(params[:id], denotation[:span][:begin], denotation[:span][:end])
    elsif params[:controller] == 'divs' || params[:pmcdoc_id].present?
      params[:id] ||= params[:div_id]
      link_to "#{denotation[:span][:begin]}-#{ denotation[:span][:end]}", spans_pmcdoc_div_path(params[:pmcdoc_id], params[:id], denotation[:span][:begin], denotation[:span][:end])
    elsif params[:controller] == 'docs' 
      if params[:id]
        link_to "#{denotation[:span][:begin]}-#{ denotation[:span][:end]}", spans_doc_path(params[:id], denotation[:span][:begin], denotation[:span][:end])
      else
        link_to "#{denotation[:span][:begin]}-#{ denotation[:span][:end]}", spans_doc_path(@doc.id, denotation[:span][:begin], denotation[:span][:end])
      end
    end
  end
end
