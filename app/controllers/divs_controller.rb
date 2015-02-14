class DivsController < ApplicationController
  include ApplicationHelper
  include AnnotationsHelper

  def index
    begin
      @divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid], order: :serial)
      raise "There is no such document." unless @divs.present?

      @search_path = doc_sourcedb_sourceid_divs_search_path(params[:sourcedb], params[:sourceid])

      @divs.each{|div| div.set_ascii_body} if (params[:encoding] == 'ascii')

      respond_to do |format|
        format.html
        format.json {render json: @divs.collect{|div| div.to_list_hash('div')}}
        format.tsv  {render text: Doc.to_tsv(@divs, 'div') }
        format.txt  {redirect_to doc_sourcedb_sourceid_show_path(params[:project_id], params[:sourcedb], params[:sourceid], format: :txt)}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to docs_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def project_divs_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless @divs.present?

      @search_path = search_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid])

      @divs.each{|div| div.set_ascii_body} if (params[:encoding] == 'ascii')

      respond_to do |format|
        format.html {render 'index'}
        format.json {render json: @divs.collect{|div| div.to_list_hash('div')} }
        format.tsv  {render text: Doc.to_tsv(@divs, 'div') }
        format.txt  {redirect_to show_project_sourcedb_sourceid_docs_path(@project.name, params[:sourcedb], params[:sourceid], format: :txt)}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to project_docs_path(@project.name), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def search
    begin
      if params[:project_id]
        @project = Project.accessible(current_user).find_by_name(params[:project_id])
        raise "There is no such project." unless @project.present?

        divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        raise "There is no such document in the project." unless divs.present?

        base = @project.docs
      else
        base = Doc
      end

      conditions = ['sourcedb = ? AND sourceid = ? AND body like ?', params[:sourcedb], params[:sourceid], "%#{params[:body]}%"] if params[:body].present?
      @search_divs = base.where(conditions).order('serial ASC')

      respond_to do |format|
        format.html
        format.json {render json: @search_divs.collect{|d| d.to_list_hash('div')}}
        format.tsv  {render text: Doc.to_tsv(@search_divs, 'div')}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? index_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid]) : doc_sourcedb_sourceid_divs_index_path(params[:sourcedb], params[:sourceid])), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render text: message, status: :unprocessable_entity}
      end
    end
  end

  # GET /docs/sourcedb/:sourcedb/sourceid/:sourceid/divs/:divid
  def show
    # TODO compatibility for PMC and Docs
    # params[:divid] ||= params[:id]
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @doc.set_ascii_body if (params[:encoding] == 'ascii')
      @content = @doc.body.gsub(/\n/, "<br>")
      @annotations = @doc.hannotations

      sort_order = sort_order(Project)
      @projects = @doc.projects.accessible(current_user).sort_by_params(sort_order)

      respond_to do |format|
        format.html {render 'docs/show'}
        format.json {render json: @doc.to_hash}
        format.txt  {render text: @doc.body}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to docs_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
        format.txt  {render status: :unprocessable_entity}
      end
    end
  end

  def project_div_show
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @doc = @project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document in the project." unless @doc.present?

      @doc.set_ascii_body if (params[:encoding] == 'ascii')
      @content = @doc.body.gsub(/\n/, "<br>")
      @annotations = @doc.hannotations(@project)

      respond_to do |format|
        format.html {render 'docs/show_in_project'}
        format.json {render json: @doc.to_hash}
        format.txt  {render text: @doc.body}
      end

    # rescue => e
    #   respond_to do |format|
    #     format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : docs_path), notice: e.message}
    #     format.json {render json: {notice:e.message}, status: :unprocessable_entity}
    #     format.txt  {render status: :unprocessable_entity}
    #   end
    end
  end
end
