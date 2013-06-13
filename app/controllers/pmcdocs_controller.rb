class PmcdocsController < ApplicationController
  autocomplete :doc, :sourceid, :full => true, :scopes => [:pmcdocs]

  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:project_id]
      @project, notice = get_project(params[:project_id])
      if @project
        @docs = @project.docs.where(:sourcedb => 'PMC', :serial => 0)
      else
        @doc = nil
      end
    else
      @docs = Doc.where(:sourcedb => 'PMC', :serial => 0)
    end

    if @docs
      @docs = @docs.sort{|a, b| a.sourceid.to_i <=> b.sourceid.to_i}
      @docs = @docs.paginate(:page => params[:page])
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
        notice = t('controller.pmcdocs.create.added_to_document_set', :num_added => num_added, :project_name => project.name)
      end
    else
      notice = t('controller.pmcdocs.create.annotation_set_not_specified')
    end

    respond_to do |format|
      if num_created + num_added + num_failed > 0
        format.html { redirect_to project_pmcdocs_path(project.name), :notice => notice }
        format.json { render :json => nil, status: :created, location: project_pmcdocs_path(project.name) }
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
    @docs = Doc.pmcdocs.where(conditions).paginate(:page => params[:page])
  end

  # DELETE /pmcdocs/:pmcid
  # DELETE /pmcdocs/:pmcid.json
  def destroy
    project = nil

    if params[:project_id]
      project = Project.find_by_name(params[:project_id])
      if project
        doc = Doc.find_by_sourcedb_and_sourceid('PMC', params[:id])
        if doc
          if doc.projects.include?(project)
            project.docs.delete(doc)
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was removed from the annotation set, #{project.name}."
          else
            notice = "the annotation set, #{project.name} does not include the document, #{doc.sourcedb}:#{doc.sourceid}."
          end
        else
          notice = "The document, PMC:#{params[:id]}, does not exist in PubAnnotation." 
        end
      else
        notice = "The annotation set, #{params[:project_id]}, does not exist."
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PMC', params[:id])
      doc.destroy
    end

    respond_to do |format|
      format.html {
        if project
          redirect_to project_pmcdocs_path(project.name), :notice => notice
        else
          redirect_to pmcdocs_path, notice: notice
        end
      }
      format.json { head :no_content }
    end
  end
end
