module RelationsHelper
  def relations_num_helper(project, options = {})
    if params[:action] == 'spans'
      relations = @doc.hrelations(project, {:begin => params[:begin], :end => params[:end]})
      relations.present? ? relations.size : 0
    else 
      if project.present?
        if options[:doc].present?
          if params[:controller] == 'projects' && options[:doc].sourcedb == 'PMC'
            project.relations.project_pmcdoc_cat_relations(options[:sourceid]).count + project.relations.project_pmcdoc_ins_relations(options[:sourceid]).count
          else  
            options[:doc].project_relations_num(project.id)
          end
        else 
          project.relations_num
        end
      else
        options[:doc].relations_num
      end
    end
  end
end
