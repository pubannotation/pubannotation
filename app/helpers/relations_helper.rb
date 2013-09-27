module RelationsHelper
  def relations_count_helper(project, options = {})
    if params[:action] == 'spans'
      relations = @doc.hrelations(project, {:spans => {:begin_pos => params[:begin], :end_pos => params[:end]}})
      relations.present? ? relations.size : 0
    else 
      if project.present?
        if options[:doc].present?
          if options[:sourceid].present?
            options[:doc].same_sourceid_relations_count
          else
            options[:doc].project_relations_count(project.id)
          end
        else 
          if project.class == Project
            Relation.project_relations_count(project.id, Relation)
          else
            project.relations_count
          end
        end
      else
        options[:doc].relations_count
      end
    end
  end
end
