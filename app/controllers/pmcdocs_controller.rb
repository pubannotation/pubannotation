class PmcdocsController < ApplicationController
  autocomplete :doc, :sourceid, :scopes => [:pmcdocs]

  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:project_id]
      @project, notice = get_project(params[:project_id])
      if @project
        @docs = @project.docs.pmcdocs
      else
        @docs = nil
      end
    else
      @docs = Doc.pmcdocs
    end

    if @docs
      @docs = Doc.order_by(@docs, params[:docs_order]).paginate(:page => params[:page])
    end
    
    respond_to do |format|
      if @docs
        format.html
        format.json { render json: @docs }
      else
        format.html { flash[:notice] = notice }
        format.json { head :unprocessable_entity }
      end
    end
  end

  # GET /pmcdocs/:pmcdoc_id
  # GET /pmcdocs/:pmcdoc_id.json
  def show
    if (params[:project_id])
      project, notice = get_project(params[:project_id])
      if project
        divs, notice = get_divs(params[:id], project)
      else
        divs = nil
      end
    else
      divs, notice = get_divs(params[:id])
    end

    respond_to do |format|
      format.html {
        if divs
          if project
            redirect_to project_pmcdoc_divs_path(params[:project_id], params[:id]), :notice => notice
          else
            redirect_to pmcdoc_divs_path(params[:id]), :notice => notice
          end
        else
          if project
            redirect_to project_pmcdocs_path(params[:project_id]), :notice => notice
          else
            redirect_to pmcdocs_path, :notice => notice
          end
        end
      }
      format.json {
        if divs
          render json: divs
        else
          head :unprocessable_entity
        end
      }
    end
  end


  # POST /pmcdocs
  # POST /pmcdocs.json
  def create
    num_created, num_added, num_failed = 0, 0, 0

    if (params[:project_id])
      project, notice = get_project(params[:project_id])
      if project
        pmcids = params[:pmcids].split(/[ ,"':|\t\n]+/).collect{|id| id.strip}
        pmcids.each do |sourceid|
          divs = Doc.find_all_by_sourcedb_and_sourceid('PMC', sourceid)
          if divs and !divs.empty?
            unless project.docs.include?(divs.first)
              divs.each {|div| project.docs << div}
              num_added += 1
            end
          else
            divs, message = gen_pmcdoc(sourceid)
            if divs
              divs.each {|div| project.docs << div}
              num_added += 1
            else
              num_failed += 1
            end
          end
        end
        notice = t('controllers.pmcdocs.create.added_to_document_set', :num_added => num_added, :project_name => project.name)
      end
    else
      notice = t('controllers.pmcdocs.create.annotation_set_not_specified')
    end

    respond_to do |format|
      if num_created + num_added + num_failed > 0
        format.html { redirect_to project_path(project.name, :accordion_id => 2), :notice => notice }
        format.json { render :json => nil, status: :created, location: project_path(project.name, :accordion_id => 2) }
      else
        format.html { redirect_to home_path, :notice => notice }
        format.json { head :unprocessable_entity }
      end
    end
  end

  def search
    conditions_array = Array.new
    conditions_array << ['sourceid like ?', "%#{params[:sourceid]}%"] if params[:sourceid].present?
    conditions_array << ['body like ?', "%#{params[:body]}%"] if params[:body].present?
    
    # Build condition
    i = 0
    conditions = Array.new
    columns = ''
    conditions_array.each do |key, val|
      key = " AND #{key}" if i > 0
      columns += key
      conditions[i] = val
      i += 1
    end
    conditions.unshift(columns)
    @docs = Doc.pmcdocs.where(conditions).order('id ASC').paginate(:page => params[:page])
    @pmc_sourceid_value = params[:sourceid]
    @pmc_body_value = params[:body]
  end

  # DELETE /pmcdocs/:pmcid
  # DELETE /pmcdocs/:pmcid.json
  def destroy
    project = nil
    if params[:project_id]
      project = Project.find_by_name(params[:project_id])
      if project
        divs = get_divs(params[:id], project)[0]
        if divs.present?
          divs.each do |div|
            project.docs.delete(div) 
          end
          notice = I18n.t('controllers.pmcdocs.destroy.document_removed_from_annotation_set', :sourcedb => divs.first.sourcedb, :sourceid => divs.first.sourceid,:project_name => project.name)
        else
          # TODO sourceid is not specified
          #notice = "the project, #{project.name} does not include the document, #{divs.first.sourcedb}:#{divs.first.sourceid}."
          notice = I18n.t('controllers.pmcdocs.destroy.project_does_not_include_document', :project_name => project.name, :sourcedb => params[:id])
        end
      else
        notice = I18n.t('controllers.pmcdocs.destroy.project_does_not_exist_in_pubannotation', :project_id => params[:project_id]) 
      end
    else
      divs = Doc.find_all_by_sourcedb_and_sourceid('PMC', params[:id])
      if divs.present?
        divs.each do |div|
          div.destroy
        end
        notice = I18n.t('controllers.pmcdocs.destroy.document_removed_from_pubannotation', :sourcedb => divs.first.sourcedb, :sourceid => divs.first.sourceid)
      else
        notice = I18n.t('controllers.pmcdocs.destroy.document_does_not_exist_in_pubannotation', :id => params[:id])
      end
    end

    respond_to do |format|
      format.html {
        if project
          redirect_to project_path(project.name, :accordion_id => 2), :notice => notice
        else
          redirect_to pmcdocs_path, notice: notice
        end
      }
      format.json { head :no_content }
    end
  end

  
  def sql
    @search_path = sql_pmcdocs_path 
    @columns = [:sourcedb, :sourceid, :section]
    begin
      if params[:project_id].present?
        # when search from inner project
        project = Project.find_by_name(params[:project_id])
        if project.present?
          @search_path = project_pmcdocs_sql_path
        else
          @redirected = true
          redirect_to @search_path
        end
      end     
      @docs = Doc.pmcdocs.sql_find(params, current_user, project ||= nil)
      if @docs.present?
        @docs = @docs.paginate(:page => params[:page], :per_page => 50)
      end
    rescue => error
      flash[:notice] = "#{t('controllers.shared.sql.invalid')} #{error}"
    end
    render 'docs/sql' unless @redirected
  end
end
