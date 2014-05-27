class DivsController < ApplicationController
  include ApplicationHelper
  include AnnotationsHelper
  
  # GET /pmcdocs/:pmcid/divs
  # GET /pmcdocs/:pmcid/divs.json
  def index
    @docs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], :order => 'serial ASC')

    if params[:project_id]
      @project_name = params[:project_id]
      @project = Project.find_by_name(@project_name)
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
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

      if params[:sort_key]
        @sort_order = flash[:sort_order]
        @sort_order.delete(@sort_order.assoc(params[:sort_key]))
        @sort_order.unshift([params[:sort_key], params[:sort_direction]])
      else
        # initialize the sort order
        @sort_order = [['name', 'ASC'], ['author', 'ASC'], ['users.username', 'ASC']]
      end

      @projects = @doc.projects.includes(:user).accessible(current_user).order(@sort_order.collect{|s| s.join(' ')}.join(', '))
      flash[:sort_order] = @sort_order
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
          flash[:notice] = notice if notice.present?
          render 'docs/show'
        }
        format.json {
          standoff = Hash.new
          # TODO pmcdoc_id => sourceid ?
          standoff[:pmcdoc_id] = params[:sourceid]
          standoff[:div_id] = params[:div_id]
          standoff[:text] = @text
          render :json => standoff #, :callback => params[:callback]
        }
        format.txt  { render :text => @text }
      else 
        format.html { redirect_to :back, notice: notice}
        format.json { head :unprocessable_entity }
        format.txt  { head :unprocessable_entity }
      end
    end
  end
end
