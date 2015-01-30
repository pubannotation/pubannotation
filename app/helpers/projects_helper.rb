module ProjectsHelper
  def namespaces_prefix_input_fields
    if @project.namespaces_prefixes.present?
      render :partial => 'namespace_prefix_input', :collection => @project.namespaces_prefixes
    else
      render :partial => 'namespace_prefix_input'
    end
  end

  def format_namespaces
    html = ''
    html += "BASE   &lt;#{@project.namespaces_base['uri']}&gt;<br />" if @project.namespaces_base.present?
    if @project.namespaces_prefixes.present?
      @project.namespaces_prefixes.each do |namespace|
        html += "PREFIX #{namespace['prefix']}: &lt;#{namespace['uri']}&gt;<br />"
      end
    end
    html.html_safe
  end

  def link_to_project(project)
    if @doc and @doc.sourcedb and @doc.sourceid 
      if @doc.has_divs? 
        if params[:begin].present? && params[:end].present?
          link_to project.name, spans_project_sourcedb_sourceid_divs_docs_path(project.name, @doc.sourcedb, @doc.sourceid, @doc.serial, params[:begin], params[:end]) 
        else
          link_to project.name, show_project_sourcedb_sourceid_divs_docs_path(project.name, @doc.sourcedb, @doc.sourceid, @doc.serial) 
        end
      else 
        if params[:begin].present? && params[:end].present?
          link_to project.name, spans_project_sourcedb_sourceid_docs_path(project.name, @doc.sourcedb, @doc.sourceid, params[:begin], params[:end]) 
        else
          link_to project.name, show_project_sourcedb_sourceid_docs_path(project.name, @doc.sourcedb, @doc.sourceid) 
        end
      end 
    else 
      link_to project.name, project_path(project.name) 
    end 
  end
end
