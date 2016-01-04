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

  def home_button
    # link_to t('activerecord.attributes.project.reference'), @project.reference, :class => 'home_button' if @project.reference.present?
    link_to image_tag('home-24.png', alt: 'Home', title: 'Home', class: 'home_button'), @project.reference, :class => 'home_button' if @project.reference.present?
  end

  def type_badge(project)
    badge, btitle = case project.process_text
      when 'manual', '手動' then [t('views.shared.manual_annotation_initial'), t('views.shared.manual_annotation')]
      when 'automatic', '自動' then [t('views.shared.automatic_annotation_initial'), t('views.shared.automatic_annotation')]
      else ['', '']
    end

    "<span class='badge' title='#{btitle}'>#{badge}</span>"
  end

  def license_display_helper(license)
    case license
    when 'CC-BY'
      '<a rel="license" href="http://creativecommons.org/licenses/by/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by/4.0/">Creative Commons Attribution 4.0 International License</a>.'
    when 'BY-SA'
      '<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.'
    when 'BY-ND'
      '<a rel="license" href="http://creativecommons.org/licenses/by-nd/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nd/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nd/4.0/">Creative Commons Attribution-NoDerivatives 4.0 International License</a>.'
    when 'BY-NC'
      '<a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc/4.0/">Creative Commons Attribution-NonCommercial 4.0 International License</a>.'
    when 'BY-NC-SA'
      '<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License</a>.'
    when 'BY-NC-ND'
      '<a rel="license" href="http://creativecommons.org/licenses/by-nc-nd/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-nd/4.0/80x15.png" /></a><br />This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-nd/4.0/">Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License</a>.'
    when nil
      'unknown'
    else
      license
    end
  end

  def link_to_project(project)
    if @doc and @doc.sourcedb and @doc.sourceid 
      if @doc.has_divs? 
        if params[:begin].present? && params[:end].present?
          link_to project.name, span_show_project_sourcedb_sourceid_divs_docs_path(project.name, @doc.sourcedb, @doc.sourceid, @doc.serial, params[:begin], params[:end]) 
        else
          link_to project.name, show_project_sourcedb_sourceid_divs_docs_path(project.name, @doc.sourcedb, @doc.sourceid, @doc.serial) 
        end
      else 
        if params[:begin].present? && params[:end].present?
          link_to project.name, span_show_project_sourcedb_sourceid_docs_path(project.name, @doc.sourcedb, @doc.sourceid, params[:begin], params[:end]) 
        else
          link_to project.name, show_project_sourcedb_sourceid_docs_path(project.name, @doc.sourcedb, @doc.sourceid) 
        end
      end 
    else 
      link_to project.name, project_path(project.name) 
    end 
  end

  def is_my_project?(project, current_user)
    if project.user == current_user
      css_class = 'check-circle'
      content_tag(:i, nil, class: "fa fa-#{css_class}")
    end
  end
end
