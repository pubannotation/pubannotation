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
    end
  end
  
  def project_annotations_zip_link_helper(project_name, options = {})
    file_path = "#{Denotation::ZIP_FILE_PATH}#{project_name}.zip"
    
    if File.exist?(file_path) == true
      # when ZIP file exists 
      html = link_to "annotation.zip", "/annotations/#{project_name}.zip", :class => 'button'
      html += content_tag :span, "#{File.ctime(file_path).strftime("#{t('controllers.shared.last_modified_at')}:%Y-%m-%d %T")}", :class => 'zip_time_stamp'
    else
      # when ZIP file deos not exists 
      delayed_job_tasks = ActiveRecord::Base.connection.execute('SELECT * FROM delayed_jobs').select{|delayed_job| delayed_job['handler'] =~ /#{project_name}/ }
      if delayed_job_tasks.blank?
        # when delayed_job exists
        link_to t('controllers.annotations.create_zip'), project_annotations_path(project_name, :delay => true), :class => 'button', :confirm => t('controllers.annotations.confirm_create_zip')
      else
        # delayed_job does not exists
        'ZIP file will be created in a few minutes.'
      end
    end    
  end
end
