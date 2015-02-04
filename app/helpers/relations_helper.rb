module RelationsHelper
  def relations_count_helper(project, options = {})
    if params[:action] == 'spans'
      relations = @doc.hrelations(project, {:begin => params[:begin], :end => params[:end]})
      relations.present? ? relations.size : 0
    else 
      if project.present?
        if options[:doc].present?
          if params[:controller] == 'projects' && options[:doc].sourcedb == 'PMC'
            project.relations.project_pmcdoc_cat_relations(options[:sourceid]).count + project.relations.project_pmcdoc_ins_relations(options[:sourceid]).count
          else  
            options[:doc].project_relations_count(project.id)
          end
        else 
          project.relations_count
        end
      else
        options[:doc].relations_count
      end
    end
  end
end
