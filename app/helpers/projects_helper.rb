module ProjectsHelper
  def project_status_text_helper(status)
    {
      1 => I18n.t('activerecord.options.project.status.released'),
      2 => I18n.t('activerecord.options.project.status.beta'),
      3 => I18n.t('activerecord.options.project.status.uploading'),
      8 => I18n.t('activerecord.options.project.status.developing'),
      9 => I18n.t('activerecord.options.project.status.testing')
    }[status] || 'N/S'
  end

  def project_process_text_helper(process)
    {
      1 => I18n.t('activerecord.options.project.process.manual'),
      2 => I18n.t('activerecord.options.project.process.automatic')
    }[process]
  end

  def project_process_link_helper(process)
    text = {
      1 => I18n.t('activerecord.options.project.process.manual'),
      2 => I18n.t('activerecord.options.project.process.automatic')
    }[process]

    path = projects_path + '?' + URI.encode_www_form_component("grid[f][process][eq]") + "=#{process}"

    link_to(text, path, style: "display:block")
  end

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

  def maintainer_link(project)
    if project.anonymize == true
      if current_user.present? && (current_user.root? || current_user == project.user)
        link_to (project.user.username + ' ' + content_tag(:i, '', class: "fa fa-user-secret", "aria-hidden" => "true", title: "anonymized")).html_safe, show_user_path(project.user.username), style: 'display:block'
      else
        '<i class="fa fa-user-secret" aria-hidden="true" title="anonymized"></i>'.html_safe
      end
    else
      link_to project.user.username, show_user_path(project.user.username), style: 'display:block'
    end
  end

  def home_button
    # link_to t('activerecord.attributes.project.reference'), @project.reference, :class => 'home_button' if @project.reference.present?
    link_to image_tag('home-24.png', alt: 'Home', title: 'Home', class: 'home_button'), @project.reference, :class => 'home_button' if @project.reference.present?
  end

  def badge_type(project)
    badge, btitle = case project.process_text
      when 'Manual', '手動' then ['<i class="fa fa-hand-pointer-o" aria-hidden="true"></i>', t('views.shared.manual_annotation')]
      when 'Automatic', '自動' then ['<i class="fa fa-cogs" aria-hidden="true"></i>', t('views.shared.automatic_annotation')]
      else ['', '']
    end

    "<span class='badge' title='#{btitle}'>#{badge}</span>"
  end

  def badge_accessibility(project)
    badge, btitle = case project.accessibility
      when 2 then ['<i class="fa fa-ban" aria-hidden="true"></i>', t('activerecord.options.project.accessibility.private')]
      when 3 then ['<i class="fa fa-bars" aria-hidden="true"></i>', t('activerecord.options.project.accessibility.blind')]
    end

    badge.present? ? "<span class='badge' title='#{btitle}'>#{badge}</span>" : ""
  end

  def icon_job(project)
    if  project.has_running_jobs?
      content_tag(:i, '', class: "fa fa-cog fa-spin fa-lg", "aria-hidden" => "true", title: "jobs")
    elsif  project.has_waiting_jobs?
      content_tag(:i, '', class: "fa fa-cog fa-pulse fa-lg", "aria-hidden" => "true", title: "jobs")
    else
      content_tag(:i, '', class: "fa fa-cog fa-lg", "aria-hidden" => "true", title: "jobs")
    end
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

  def textae_config_display_helper(config_url)
    link_to(config_url, config_url) + ' ' + link_to(fa_icon('pencil', title:"edit"), config_url.chomp('.json'))
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

  def comparison_link(project)
    if File.exist?(project.comparison_path)
      link_to 'See the last comparison', comparison_project_path(project.name)
    else
    end
  end

  def project_selector_icon(selected)
    if selected
      'fa-minus'
    else
      'fa-plus'
    end
  end
end
