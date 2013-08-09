class PmdocsController < ApplicationController
  autocomplete :doc, :sourceid, :scopes => [:pmdocs]
  
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    if params[:project_id]
      @project, notice = get_project(params[:project_id])
      if @project
        @docs = @project.docs.pmdocs
      else
        @docs = nil
      end
    else
      @docs = Doc.pmdocs
    end

    if @docs
      @docs = Doc.order_by(@docs, params[:docs_order])
    end
    
    respond_to do |format|
      if @docs
        format.html { @docs = @docs.paginate(:page => params[:page]) }
        format.json { render json: @docs }
      else
        format.html { flash[:notice] = notice }
        format.json { head :unprocessable_entity }
      end
    end
  end

  # GET /pmdocs/:pmid
  # GET /pmdocs/:pmid.json
  def show
    if (params[:project_id])
      @project, notice = get_project(params[:project_id])
      if @project
        @doc, notice = get_doc('PubMed', params[:id], 0, @project)
        @annotations = get_annotations(@project, @doc)
      else
        @doc = nil
      end
    else
      @doc, notice = get_doc('PubMed', params[:id])
      @projects = get_projects(@doc)
    end

    if @doc
      @text = @doc.body
      if (params[:encoding] == 'ascii')
        asciitext = get_ascii_text(@text)
        @text = asciitext
      end
    end

    respond_to do |format|
      if @doc
        format.html {
          flash[:notice] = notice
          render 'docs/show'
        }
        format.json {
          standoff = Hash.new
          standoff[:pmdoc_id] = params[:id]
          standoff[:text] = @text
          render :json => standoff #, :callback => params[:callback]
        }
        format.txt  { render :text => @text }
      else 
        format.html { redirect_to pmdocs_path, notice: notice}
        format.json { head :unprocessable_entity }
        format.txt  { head :unprocessable_entity }
      end
    end
  end
  
  # GET /pmdocs/:begin/:end
  def spans
    @doc, notice = get_doc('PubMed', params[:id])
    if params[:encoding] == 'ascii'
      body = get_ascii_text(@doc.body)
      # difference of length after convert doc.body into ascii
      # ascii_body_additional = body.length -  @doc.body.length
    else
      body = @doc.body
    end
    begin_pos = params[:begin].to_i
    end_pos = params[:end].to_i
    if params[:context_window].present?
      prev_begin_pos = begin_pos - params[:context_window].to_i
      prev_end_pos = begin_pos - 1
      @prev_text = body[prev_begin_pos...prev_end_pos] 

      next_begin_pos = begin_pos + 1
      next_end_pos = begin_pos + params[:context_window].to_i
      @next_text = body[next_begin_pos...next_end_pos] 
    end
    @spans = body[begin_pos...end_pos]
  end


  # POST /pmdocs
  # POST /pmdocs.json
  def create
    num_created, num_added, num_failed = 0, 0, 0

    if (params[:project_id])
      project, notice = get_project(params[:project_id])
      if project
        pmids = params[:pmids].split(/[ ,"':|\t\n]+/).collect{|id| id.strip}
        pmids.each do |sourceid|
          doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PubMed', sourceid, 0)
          if doc
            unless project.docs.include?(doc)
              project.docs << doc
              num_added += 1
            end
          else
            doc = gen_pmdoc(sourceid)
            if doc
              project.docs << doc
              num_added += 1
            else
              num_failed += 1
            end
          end
        end
        notice = t('controllers.pmdocs.create.added_to_document_set', :num_added => num_added, :project_name => project.name)

      end
    else
      notice = t('controllers.pmdocs.create.annotation_set_not_specified')
    end

    respond_to do |format|
      if num_created + num_added + num_failed > 0
        format.html { redirect_to project_path(project.name, :accordion_id => 1), :notice => notice }
        format.json { render :json => nil, status: :created, location: project_path(project.name, :accordion_id => 1) }
      else
        format.html { redirect_to home_path, :notice => notice }
        format.json { head :unprocessable_entity }
      end
    end
  end


  # PUT /pmdocs/:pmid
  # PUT /pmdocs/:pmid.json
  def update
    doc    = nil
    project = nil

    if params[:project_id]
      project = Project.find_by_name(params[:project_id])
      if project
        doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
        if doc
          unless doc.projects.include?(project)
            project.docs << doc
            notice = t('controllers.pmdocs.update.added_to_annotationset', :sourcedb => doc.sourcedb, :sourceid => doc.sourceid, :project_name => project.name)
          end
        else
          doc = gen_pmdoc(params[:id])
          if doc
            project.docs << doc
            notice = t('controllers.pmdocs.update.created_in_annotation_set', :sourcedb => doc.sourcedb, :sourceid => doc.sourceid, :project_name => project.name)
          else
            notice = t('controllers.pmdocs.update.not_created', :id => params[:id])
          end
        end
      else
        notice = t('controllers.pmdocs.update.does_not_exist', :project_id => params[:project_id])
        doc = nil
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      unless doc
        doc = gen_pmdoc(params[:id])
        if doc
          notice = t('controllers.pmdocs.update.successfuly_created', :id => params[:id]) 
        else
          notice = t('controllers.pmdocs.update.not_created', :id => params[:id])
        end
      end
    end

    respond_to do |format|
      format.html {
        if project
          redirect_to project_path(project.name, :accordion_id => 1), :notice => notice, :method => :get
        else
          redirect_to pmdocs_path, notice: notice
        end
      }

      format.json {
        if doc and (project or !params[:project_id])
          head :no_content
        else
          head :unprocessable_entity
        end
      }
    end
  end

  # DELETE /pmdocs/:pmid
  # DELETE /pmdocs/:pmid.json
  def destroy
    project = nil

    if params[:project_id]
      project = Project.find_by_name(params[:project_id])
      if project
        doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
        if doc
          if doc.projects.include?(project)
            project.docs.delete(doc)
            notice = t('controllers.pmdocs.destroy.removed_from_annotation_set', :sourcedb => doc.sourcedb, :sourceid => doc.sourceid, :project_name => project.name)
          else
            notice = t('controllers.pmdocs.destroy.does_not_include_document', :project_name => project.name, :sourcedb => doc.sourcedb, :sourceid => doc.sourceid)
          end
        else
          notice = t('controllers.pmdocs.destroy.does_not_exist_in_pubannotation', :id => params[:id]) 
        end
      else
        notice = t('controllers.pmdocs.destroy.does_not_exist', :project_id => params[:project_id])
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      doc.destroy
    end

    respond_to do |format|
      format.html {
        if project
          redirect_to project_path(project.name, :accordion_id => 1), :notice => notice
        else
          redirect_to pmdocs_path, notice: notice
        end
      }
      format.json { head :no_content }
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
    @docs = Doc.pmdocs.where(conditions).paginate(:page => params[:page])
    @pm_sourceid_value = params[:sourceid]
    @pm_body_value = params[:body]
  end
end
