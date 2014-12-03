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
end
