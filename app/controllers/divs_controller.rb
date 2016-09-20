class DivsController < ApplicationController
  include ApplicationHelper
  include AnnotationsHelper
  include DivsHelper
  before_filter :find_doc_and_divs, only: [:index, :index_in_project]
  before_filter :find_doc_and_div, only: [:show, :show_in_project]

  def index
    begin
      # TODO can't search divs
      # if params[:keywords].present?
      #   search_results = Doc.search_docs({body: params[:keywords].strip.downcase, sourcedb: params[:sourcedb], sourceid: params[:sourceid], page:params[:page]})
      #   @search_count = search_results[:total]
      #   # @divs = @search_count > 0 ? search_results[:results] : []
      # end
      # @divs.each{|div| div.set_ascii_body} if (params[:encoding] == 'ascii')

      respond_to do |format|
        format.html
        format.json {render json: @divs.collect{|div| div.to_list_hash}}
        format.tsv  {render text: Div.to_tsv(@divs) }
        format.txt  {redirect_to doc_sourcedb_sourceid_show_path(params[:sourcedb], params[:sourceid], format: :txt)}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def index_in_project
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      # TODO can't search divs
      # if params[:keywords].present?
      #   search_results = Doc.search_docs({body: params[:keywords].strip.downcase, project_id: @project.id, sourcedb: params[:sourcedb], sourceid: params[:sourceid], page:params[:page]})
      #   @search_count = search_results[:total]
      #   @divs = @search_count > 0 ? search_results[:results] : []
      # end
      # @divs.each{|div| div.set_ascii_body} if (params[:encoding] == 'ascii')

      respond_to do |format|
        format.html 
        format.json {render json: @divs.collect{|div| div.to_list_hash} }
        format.tsv  {render text: Doc.to_tsv(@divs) }
        format.txt  {redirect_to show_project_sourcedb_sourceid_docs_path(@project.name, params[:sourcedb], params[:sourceid], format: :txt)}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  # GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divid
  def show
    # TODO compatibility for PMC and Docs
    # params[:divid] ||= params[:id]
    begin
      sort_order = sort_order(Project)
      @projects = @doc.projects.accessible(current_user).order(sort_order)

      @annotations = @doc.hannotations(@projects.select{|p| p.annotations_accessible?(current_user)})
      if @annotations[:tracks].present?
        @annotations[:denotations] = @annotations[:tracks].inject([]){|denotations, track| denotations += (track[:denotations] || [])}
        @annotations[:relations] = @annotations[:tracks].inject([]){|relations, track| relations += (track[:relations] || [])}
        @annotations[:modifications] = @annotations[:tracks].inject([]){|modifications, track| modifications += (track[:modifications] || [])}
      end

      serial = params[:divid].to_i
      doc = Doc.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid]).count
      divs_count = doc.divs.count
      @prev_path = serial > 0 ? doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], serial - 1) : nil
      @next_path = serial < divs_count - 1 ? doc_sourcedb_sourceid_divs_show_path(params[:sourcedb], params[:sourceid], serial + 1) : nil

      respond_to do |format|
        format.html {render 'docs/show'}
        format.json {render json: @doc.to_hash}
        format.txt  {render text: @doc.body}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to home_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def show_in_project
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @annotations = @doc.hannotations(@project)

      serial = params[:divid].to_i
      divs_count = @doc.divs.count
      @prev_path = serial > 0 ? show_project_sourcedb_sourceid_divs_docs_path(params[:project_id], params[:sourcedb], params[:sourceid], serial - 1) : nil
      @next_path = serial < divs_count - 1 ? show_project_sourcedb_sourceid_divs_docs_path(params[:project_id], params[:sourcedb], params[:sourceid], serial + 1) : nil

      respond_to do |format|
        format.html {render 'docs/show_in_project'}
        format.json {render json: @doc.to_hash}
        format.txt  {render text: @doc.body}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : home_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  private

  def find_doc_and_divs
    @doc = Doc.find_base_doc(params)
    @divs = @doc.divs
    raise "There is no such document." if @divs.blank?
    @divs_count = @divs.count
  end

  def find_doc_and_div
    @doc = Doc.find_base_doc(params)
    @div = @doc.divs.find_by_serial(params[:divid])
    @content = div_body(@div)
    raise "There is no such document in the project." unless @doc.present?
  end
end
