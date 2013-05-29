class PmdocsController < ApplicationController
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    if params[:project_id]
      @project, notice = get_project(params[:project_id])
      if @project
        @docs = @project.docs.where(:sourcedb => 'PubMed', :serial => 0)
      else
        @docs = nil
      end
    else
      @docs = Doc.where(:sourcedb => 'PubMed', :serial => 0)
    end

    if @docs
      @docs = @docs.sort{|a, b| a.sourceid.to_i <=> b.sourceid.to_i}
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
        notice = "#{num_added} documents were added to the document set, #{project.name}."
      end
    else
      notice = "Annotation set is not specified."
    end

    respond_to do |format|
      if num_created + num_added + num_failed > 0
        format.html { redirect_to project_pmdocs_path(project.name), :notice => notice }
        format.json { render :json => nil, status: :created, location: project_pmdocs_path(project.name) }
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
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was added to the annotation set, #{project.name}."
          end
        else
          doc = gen_pmdoc(params[:id])
          if doc
            project.docs << doc
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was created in the annotation set, #{project.name}."
          else
            notice = "The document, PubMed:#{params[:id]}, could not be created." 
          end
        end
      else
        notice = "The annotation set, #{params[:project_id]}, does not exist."
        doc = nil
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      unless doc
        doc = gen_pmdoc(params[:id])
        if doc
          notice = "The document, PubMed:#{params[:id]}, was successfuly created." 
        else
          notice = "The document, PubMed:#{params[:id]}, could not be created." 
        end
      end
    end

    respond_to do |format|
      format.html {
        if project
          redirect_to project_pmdocs_path(project.name), :notice => notice, :method => :get
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
            notice = "The document, #{doc.sourcedb}:#{doc.sourceid}, was removed from the annotation set, #{project.name}."
          else
            notice = "the annotation set, #{project.name} does not include the document, #{doc.sourcedb}:#{doc.sourceid}."
          end
        else
          notice = "The document, PubMed:#{params[:id]}, does not exist in PubAnnotation." 
        end
      else
        notice = "The annotation set, #{params[:project_id]}, does not exist."
      end
    else
      doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])
      doc.destroy
    end

    respond_to do |format|
      format.html {
        if project
          redirect_to project_pmdocs_path(project.name), :notice => notice
        else
          redirect_to pmdocs_path, notice: notice
        end
      }
      format.json { head :no_content }
    end
  end

end
