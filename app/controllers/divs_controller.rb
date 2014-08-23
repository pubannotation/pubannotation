class DivsController < ApplicationController
  include ApplicationHelper
  include AnnotationsHelper
  
  # GET /pmcdocs/:pmcid/divs
  # GET /pmcdocs/:pmcid/divs.json
  def index
    @docs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], :order => 'serial ASC')
    @docs.each{|doc| doc.ascii_body} if (params[:encoding] == 'ascii')
    @docs_hash = @docs.collect{|doc| doc.to_hash}

    if params[:project_id]
      @project_name = params[:project_id]
      @project = Project.find_by_name(@project_name)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs_hash}
    end
  end
  
  # GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divid
  def show
    # TODO compatibility for PMC and Docs
    params[:div_id]   ||= params[:id]
    if (params[:project_id])
      @project, notice = get_project(params[:project_id])
      if @project
        @doc, notice = get_doc(params[:sourcedb], params[:sourceid], params[:div_id], @project)
        @annotations = get_annotations(@project, @doc)
      else
        @doc = nil
      end
    else
      @doc, notice = get_doc(params[:sourcedb], params[:sourceid], params[:div_id])
      @sort_order = sort_order(Project)
      @projects = @doc.projects.accessible(current_user).sort_by_params(@sort_order)
    end

    if @doc
      @doc.ascii_body if (params[:encoding] == 'ascii')
      @doc_hash = @doc.to_hash
    end

    respond_to do |format|
      if @doc
        format.html {
          flash[:notice] = notice if notice.present?
          render 'docs/show'
        }
        format.json {render json: @doc_hash}
        format.txt  { render :text => @doc.body }
      else 
        format.html { redirect_to :back, notice: notice}
        format.json { head :unprocessable_entity }
        format.txt  { head :unprocessable_entity }
      end
    end
  end
end
