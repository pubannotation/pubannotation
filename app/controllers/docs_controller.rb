require 'zip/zip'

class DocsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :only => [:new, :edit, :create, :generate, :create_project_docs, :update, :destroy, :delete_project_docs]
  after_filter :set_access_control_headers
  # JSON POST
  before_filter :http_basic_authenticate, :only => :create_project_docs, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}
  skip_before_filter :authenticate_user!, :verify_authenticity_token, :if => Proc.new{|c| c.request.format == 'application/jsonrequest'}
  include DenotationsHelper

  # GET /docs
  # GET /docs.json
  def index
    if params[:project_id].present?
      @project = Project.includes(:docs).where(['name =?', params[:project_id]]).first
      @docs = @project.docs
      @docs.each{|doc| doc.ascii_body} if (params[:encoding] == 'ascii')
      @docs_hash = @docs.collect{|doc| doc.to_hash}
      @search_path = search_project_docs_path(@project.name)
    else
      @docs = Doc
      @docs.each{|doc| doc.ascii_body} if (params[:encoding] == 'ascii')
      @docs_hash = {message: "too many"}
      @search_path = search_docs_path
    end

    @sort_order = sort_order(Doc)
    @source_docs = @docs.where(serial: 0).sort_by_params(@sort_order).paginate(:page => params[:page])
    flash[:sort_order] = @sort_order
    respond_to do |format|
      format.html
      format.json { render json: @docs_hash}
    end
  end
 
  def records
    if params[:project_id]
      @project, notice = get_project(params[:project_id])
      @new_doc_src = new_project_doc_path
      if @project
        @docs = @project.docs.order('sourcedb ASC').order('sourceid ASC').order('serial ASC')
      else
        @docs = nil
      end
    else
      @docs = Doc.order('sourcedb ASC').order('sourceid ASC').order('serial ASC')
      @new_doc_src = new_doc_path
    end

    @docs.each{|doc| doc.ascii_body} if (params[:encoding] == 'ascii')

    respond_to do |format|
      if @docs
        format.html { @docs = @docs.paginate(:page => params[:page]) }
        format.json { render json: @docs }
        format.txt  {
          file_name = (@project)? @project.name + ".zip" : "docs.zip"
          t = Tempfile.new("pubann-temp-filename-#{Time.now}")
          Zip::ZipOutputStream.open(t.path) do |z|
            @docs.each do |doc|
              title = "%s-%s-%02d-%s" % [doc.sourcedb, doc.sourceid, doc.serial, doc.section]
              title.sub!(/\.$/, '')
              title.gsub!(' ', '_')
              title += ".txt" unless title.end_with?(".txt")
              z.put_next_entry(title)
              z.print doc.body
            end
          end
          send_file t.path, :type => 'application/zip',
                            :disposition => 'attachment',
                            :filename => file_name
          t.close

          # texts = @docs.collect{|doc| doc.body}
          # render text: texts.join("\n----------\n")
        }
      else
        format.html { flash[:notice] = notice }
        format.json { head :unprocessable_entity }
        format.txt  { head :unprocessable_entity }
      end
    end
  end
 
  def sourcedb_index
    if params[:project_id].present?
      project = Project.find_by_name(params[:project_id]) 
      docs = project.docs
    else
      docs = Doc
    end
    @source_dbs = docs.select(:sourcedb).source_dbs.uniq
  end 
 
  def sourceid_index
    if params[:project_id].present?
      @project = Project.find_by_name(params[:project_id]) 
      docs = @project.docs.where(['sourcedb = ?', params[:sourcedb]])
    else
      docs = Doc.where(['sourcedb = ?', params[:sourcedb]])
      @search_path = search_docs_path
    end

    @sort_order = sort_order(Doc)
    @source_docs = docs.where(serial: 0).sort_by_params(@sort_order).paginate(:page => params[:page])
    flash[:sort_order] = @sort_order
  end 
    
  def search
    if params[:project_id].present?
      @project = Project.find_by_name(params[:project_id])
      docs = @project.docs
    else
      docs = Doc
    end
    conditions_array = Array.new
    conditions_array << ['sourcedb = ?', "#{params[:sourcedb]}"] if params[:sourcedb].present?
    conditions_array << ['sourceid like ?', "#{params[:sourceid]}%"] if params[:sourceid].present?
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
    @source_docs = docs.where(conditions).group(:sourcedb).group(:sourceid).order('sourcedb ASC').order('CAST(sourceid AS INT) ASC').paginate(:page => params[:page])
    flash[:notice] = t('controllers.docs.search.not_found') if @source_docs.blank?
  end
  
  # GET /docs/1
  # GET /docs/1.json
  def show
    if params[:id].present?
      @doc = Doc.find(params[:id])
    elsif params[:sourcedb].present? && params[:sourceid].present?
      docs = Doc.where('sourcedb = ? AND sourceid = ?', params[:sourcedb], params[:sourceid])
      if docs.length == 1
        @doc = docs.first
      end
    end
    
    @project, notice = get_project(params[:project_id])
    if @doc.present?
      @doc.ascii_body if (params[:encoding] == 'ascii')
      @doc_hash = @doc.to_hash
      @sort_order = sort_order(Project)
      @projects = @doc.projects.accessible(current_user).sort_by_params(@sort_order)
      flash[:sort_order] = @sort_order

      respond_to do |format|
        format.html # show.html.erb
        format.json {render json: @doc_hash}
      end
    elsif docs.present?
      # when same sourcedb and sourceid docs present => redirect to divs#index
      if @project.present?
        redirect_to index_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid])
      else
        redirect_to doc_sourcedb_sourceid_divs_index_path
      end

    end
  end

  def divs_index
  end

  def spans
    sourcedb, sourceid, serial, id = get_docspec(params)
    if params[:project_id].present?
      @project, flash[:notice] = get_project(params[:project_id])
      if @project
        @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, @project)
        @project_denotations = get_project_denotations([@project], @doc, params)
      end
    else
      @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial)
      @sort_order = sort_order(Project)
      @projects = Project.id_in(@doc.spans_projects(params).collect{|project| project.id}).sort_by_params(@sort_order) if @doc.spans_projects(params).present?
      flash[:sort_order] = @sort_order
      if @doc.present? && @projects.present?
        @project_denotations = get_project_denotations(@projects, @doc, params)
      end
      @annotations_projects_check = true
      @annotations_path = "#{url_for(:only_path => true)}/annotations"
    end
    @spans, @prev_text, @next_text = @doc.spans(params)
    @text = @doc.text(params)
    @highlight_text = @doc.spans_highlight(params)
    respond_to do |format|
      format.html { render 'docs/spans'}
      format.txt { 
        render text: @text
      }
      format.json { 
        if @project_denotations.present?
          @denotations = Array.new
          @project_denotations.each do  |project_denotation|
           project_denotation[:denotations].each do |denotation|
             @denotations << denotation.select{|key| key == :span}
           end
          end
        end
        json = {
          text: @text,
          focus: get_focus({params: params}) 
        }
        render json: json
      }
      format.csv { 
        send_data @doc.to_csv(params)
      }
    end
  end
  
  def spans_index
    sourcedb, sourceid, serial, id = get_docspec(params)
    if params[:project_id].present?
      @project, flash[:notice] = get_project(params[:project_id])
      if @project
        @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, @project)
        if @doc
          annotations = get_annotations(@project, @doc, :encoding => params[:encoding], :format => params[:format])
          @denotations = annotations[:denotations]
        end
      end
    else
      @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, nil, id)
      if @doc
        @denotations = @doc.denotations.order('begin ASC').collect {|ca| ca.get_hash(doc: @doc, format: params[:format])}
      end
    end
    if @denotations.present?
      @denotations = @denotations.uniq{|denotation| denotation[:span]}
    end
    respond_to do |format|
      format.html { render 'docs/spans_index'}
      format.json { 
        annotations_json = get_annotations_for_json(@project, @doc, :encoding => params[:encoding])
        json = {text: annotations_json[:text], target: annotations_json[:target], denotations: @denotations} 
        render :json => json
      }
    end    
  end

  # GET /docs/new
  # GET /docs/new.json
  def new
    @doc = Doc.new
    @project, notice = get_project(params[:project_id])
    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @doc }
    end
  end

  # GET /docs/1/edit
  def edit
    @doc = Doc.find(params[:id])
  end

  # POST /docs
  # POST /docs.json
  def create
    @doc = Doc.new(params[:doc])
    respond_to do |format|
      if @doc.save
        @project, notice = get_project(params[:project_id])
        @project.docs << @doc if @project.present?
        get_project(params[:project_id])
        format.html { 
          if @project.present?
            redirect_to project_doc_path(@project.name, @doc), notice: t('controllers.shared.successfully_created', :model => t('activerecord.models.doc'))
          else
            redirect_to @doc, notice: t('controllers.shared.successfully_created', :model => t('activerecord.models.doc'))
          end 
        }
        format.json { render json: @doc, status: :created, location: @doc }
      else
        format.html { render action: "new" }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

  def create_project_docs
    project, message = get_project(params[:project_id])

    docs =  if params[:ids].present? && params[:sourcedb].present?
              params[:ids].split(/[ ,"':|\t\n]+/).collect{|id| id.strip}.collect{|id| {source_db:params[:sourcedb], source_id:id}}
            elsif params[:docs].present?
              params[:docs].collect{|d| d.symbolize_keys}
            end

    num_created, num_added, num_failed = 0, 0, 0
    if project && docs
      begin
        num_created, num_added, num_failed = project.add_docs_from_json(docs, current_user)
      rescue => e
        message = e.message
      end
    end
    result = {:created => num_created, :added => num_added, :failed => num_failed}

    respond_to do |format|
      format.html {
        notice = result.collect{|k,v| "#{k}: #{v}"}.join(', ')
        redirect_to project_docs_path(project.name), :notice => notice
      }
      format.json {
        if num_created > 0 || num_added > 0
          render :json => result, status: :created, location: project_docs_path(project.name)
        else
          render :json => result, status: :unprocessable_entity
        end
      }
    end  
  end

  # PUT /docs/1
  # PUT /docs/1.json
  def update
    params[:doc][:body].gsub!(/\r\n/, "\n")
    @doc = Doc.find(params[:id])

    respond_to do |format|
      if @doc.update_attributes(params[:doc])
        format.html { redirect_to @doc, notice: t('controllers.shared.successfully_updated', :model => t('activerecord.models.doc')) }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /docs/1
  # DELETE /docs/1.json
  def destroy
    @doc = Doc.find(params[:id])
    if params[:project_id].present?
      project = Project.find_by_name(params[:project_id])
      project.docs.delete(@doc)
      redirect_path = records_project_docs_path(params[:project_id])
    else
      @doc.destroy
      redirect_path = docs_url
    end

    respond_to do |format|
      format.html { redirect_to redirect_path }
      format.json { head :no_content }
    end
  end
  
  def delete_project_docs
    project = Project.find_by_name(params[:project_id])
    docs = project.docs.where(:sourcedb => params[:sourcedb]).where(:sourceid => params[:sourceid])
    docs.each {|d| annotations_destroy_all_helper(d, project)}
    project.docs.delete(docs) 
    redirect_to :back
  end

  private

  def set_access_control_headers
    allowed_origins = ['http://localhost', 'http://localhost:8000', 'http://bionlp.dbcls.jp']
    origin = request.env['HTTP_ORIGIN']
    if allowed_origins.include?(origin)
      headers['Access-Control-Allow-Origin'] = origin
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Allow-Headers'] = 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token, X-Prototype-Version'
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers['Access-Control-Max-Age'] = "1728000"
    end
  end

end
