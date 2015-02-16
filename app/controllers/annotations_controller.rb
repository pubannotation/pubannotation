require 'zip/zip'

class AnnotationsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :except => [:index, :doc_annotations_index, :div_annotations_index, :project_doc_annotations_index, :project_div_annotations_index, :doc_annotations_visualize, :div_annotations_visualize, :show, :create, :annotations_index, :annotations, :project_annotations_zip]
  after_filter :set_access_control_headers
  include DenotationsHelper

  def project_annotations_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      # retrieve annotations to all the documents
      annotations_collection = @project.annotations_collection(params[:encoding])

      respond_to do |format|
        format.ttl {
          ttl = ''
          header_length = 0
          annotations_collection.each_with_index do |ann, i|
            if i == 0
              ttl = get_conversion(ann, @project.rdfwriter)
              ttl.each_line{|l| break unless l.start_with?('@'); header_length += 1}
            else
              ttl += get_conversion(ann, @project.rdfwriter).split(/\n/)[header_length .. -1].join("\n")
            end
            ttl += "\n" unless ttl.end_with?("\n")
          end
          render :text => ttl, :content_type => 'application/x-turtle', :filename => @project.name
        }
      end
    end
  end

  # annotations for doc without project
  def doc_annotations_index
    begin
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]
        @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

        @doc.set_ascii_body if params[:encoding] == 'ascii'
        @annotations = @doc.hannotations(nil, @span)
        tracks = @annotations[:tracks] || []
        @project_annotations_index = tracks.inject({}) {|index, track| index[track[:project]] = track; index}

        sort_order = sort_order(Project)
        @projects = @doc.projects.accessible(current_user).sort_by_params(sort_order)

        respond_to do |format|
          format.html {render 'index'}
          format.json {render json: @annotations}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : docs_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  # annotations for doc without project
  def div_annotations_index
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      @doc.set_ascii_body if params[:encoding] == 'ascii'
      @annotations = @doc.hannotations(nil, @span)

      tracks = @annotations[:tracks] || []
      @project_annotations_index = tracks.inject({}) {|index, track| index[track[:project]] = track; index}

      sort_order = sort_order(Project)
      @projects = @doc.projects.accessible(current_user).sort_by_params(sort_order)

      respond_to do |format|
        format.html {render 'index'}
        format.json {render json: @annotations}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to (@project.present? ? project_docs_path(@project.name) : docs_path), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def project_doc_annotations_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      divs = @project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to index_project_sourcedb_sourceid_divs_docs_path(@project.name, params[:sourcedb], params[:sourceid])}
          format.json {
            divs.each{|div| div.set_ascii_body} if params[:encoding] == 'ascii'
            render json: divs.collect{|div| div.hannotations}
          }
        end
      else
        @doc = divs[0]

        @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

        @doc.set_ascii_body if (params[:encoding] == 'ascii')
        # @content = @doc.body.gsub(/\n/, "<br>")
        @annotations = @doc.hannotations(@project, @span)

        respond_to do |format|
          format.html {render 'index_in_project'}
          format.json {render json: @annotations}
        end
      end

    # rescue => e
    #   respond_to do |format|
    #     format.html {redirect_to project_docs_path(@project.name), notice: e.message}
    #     format.json {render json: {notice:e.message}, status: :unprocessable_entity}
    #   end
    end
  end

  def project_div_annotations_index
    begin
      @project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      @doc = @project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document in the project." unless @doc.present?

      @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      @doc.set_ascii_body if (params[:encoding] == 'ascii')
      @annotations = @doc.hannotations(@project, @span)

      respond_to do |format|
        format.html {render 'index_in_project'}
        format.json {render json: @annotations}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to project_docs_path(@project.name), notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def doc_annotations_visualize
    begin
      divs = Doc.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      raise "There is no such document in the project." unless divs.present?

      if divs.length > 1
        respond_to do |format|
          format.html {redirect_to doc_sourcedb_sourceid_divs_index_path params}
        end
      else
        @doc = divs[0]
        raise "There is no such document." unless @doc.present?

        @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

        @doc.set_ascii_body if params[:encoding] == 'ascii'
        @annotations = @doc.hannotations(nil, @span)

        @track_annotations = @annotations[:tracks]
        @track_annotations.each {|a| a[:text] = @annotations[:text]}

        respond_to do |format|
          format.html {render 'visualize_tracks'}
          format.json {render json: @annotations}
        end
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to docs_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def div_annotations_visualize
    begin
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      raise "There is no such document." unless @doc.present?

      @span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      @doc.set_ascii_body if params[:encoding] == 'ascii'
      @annotations = @doc.hannotations(nil, @span)

      @track_annotations = @annotations[:tracks]
      @track_annotations.each {|a| a[:text] = @annotations[:text]}

      respond_to do |format|
        format.html {render 'visualize_tracks'}
        format.json {render json: @annotations}
      end

    rescue => e
      respond_to do |format|
        format.html {redirect_to docs_path, notice: e.message}
        format.json {render json: {notice:e.message}, status: :unprocessable_entity}
      end
    end
  end

  def annotations
    sourcedb, sourceid, serial, id = get_docspec(params)
    params[:project_id] = params[:project] if params[:project].present?
    @project = params[:projects].split(',').map{|n| Projects.accessible(current_user).find_by_name(n)} if params[:projects].present?

    span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

    if params[:project_id].present?
      @project, flash[:notice] = get_project(params[:project_id])
      if @project
        @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, @project)
        @project_denotations = @doc.denotations_in_tracks(@project, span)
      end
    else
      @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, nil, id)
      if params[:projects].present?
        projects = Project.name_in(params[:projects].split(','))
      else
        projects = @doc.projects
      end
      @project_denotations = @doc.denotations_in_tracks(projects, span)
    end

    if @doc.present?
      @spans, @prev_text, @next_text = @doc.spans(params)
      annotations = @doc.hannotations(@project, span)

      # ToDo: to process tracks
      @denotations = annotations[:denotations]
      @relations = annotations[:relations]
      @modifications = annotations[:modifications]
      respond_to do |format|
        format.html { render 'annotations'}
        format.json { render :json => annotations, :callback => params[:callback] }
      end
    end
  end

  # POST /annotations
  # POST /annotations.json
  def create
    begin
      if params[:project_id].present?
        authenticate_user!
        project = Project.editable(current_user).find_by_name(params[:project_id])
        raise "There is no such project in your management." unless project.present?
      end

      mode = :addition if params[:mode] == 'addition' || params[:mode] == 'add'

      sourcedb, sourceid, divno = get_docspec(params)
      divnos = divno.respond_to?(:each) ? divno : [divno]
      divs = divnos.collect{|no| get_doc(sourcedb, sourceid, no)[0]}
      raise ArgumentError, "There is no such document." if divs[0].nil? || (project.present? && !project.docs.include?(divs[0]))

      if params[:annotations]
        annotations = params[:annotations].symbolize_keys
      elsif params[:text].present?
        annotations = {:text => params[:text]}
        annotations[:denotations] = params[:denotations] if params[:denotations].present?
        annotations[:relations] = params[:relations] if params[:relations].present?
        annotations[:modifications] = params[:modifications] if params[:modifications].present?
      else
        raise ArgumentError, t('controllers.annotations.create.no_annotation')
      end

      annotations = normalize_annotations!(annotations)

      if annotations[:text].length < 5000 || project.nil?
        result = Shared.store_annotations(annotations, project, divs, {:mode => mode})
      else
        project.notices.create({method: 'start_delay_store_annotations'}) if project.present?
        Shared.delay.store_annotations(annotations, project, divs, {mode: mode, delayed: true})
        result = {message: t('controllers.annotations.create.delayed_job')}
      end

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {render :json => result, :status => :created}
      end

    rescue ArgumentError => e

      respond_to do |format|
        format.html {
          if project
            redirect_to project_path(project.name), notice: e.message
          else
            redirect_to home_path, notice: e.message
          end
        }
        format.json {
          render :json => {error: e.message}, :status => :unprocessable_entity
        }
      end

    end
  end

  def generate
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      doc = if params[:divid].present?
        project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      else
        project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      end
      raise "There is no such document in the project." unless doc.present?

      span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      doc.set_ascii_body if (params[:encoding] == 'ascii')
      annotations = doc.hannotations(project, span)

      annotations = gen_annotations(annotations, params[:annotation_server])
      normalize_annotations!(annotations)
      result      = Shared.save_annotations(annotations, project, doc)
      notice      = "annotations were successfully obtained."

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {}
      end
    end
  end

  def create_from_zip
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      if params[:zipfile].present? && params[:zipfile].content_type == 'application/zip'
        options = {mode: :addition} if params[:mode] == 'addition' || params[:mode] == 'add'
        project.notices.create({method: 'annotations batch upload'})
        messages = project.delay.create_annotations_from_zip(params[:zipfile].path, options)
      end

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {}
      end
    # rescue => e
    #   render_status_error(:not_found)
    end
  end

  # redirect to project annotations zip
  def project_annotations_zip
    begin
      project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_zip_system_path)
        # redirect_to "/annotations/#{project.annotations_zip_file_name}"
        redirect_to project.annotations_zip_path
      else
        raise "annotation zip file does not exist."
      end
    rescue => e
      render_status_error(:not_found)
    end
  end

  def create_project_annotations_zip
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      project.notices.create({method: "create annotations zip"})
      project.delay.create_annotations_zip(params[:encoding])
    rescue => e
      flash[:notice] = notice
    end
    redirect_to :back
  end

  def delete_project_annotations_zip
    begin
      status_error = false
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_zip_system_path)
        if project.user == current_user 
          File.unlink(project.annotations_zip_system_path)
          flash[:notice] = t('views.shared.zip.deleted')
        else
          status_error = true
          render_status_error(:forbidden)
        end
      else
        status_error = true
        render_status_error(:not_found)
      end
    rescue => e
      flash[:notice] = e.message
    ensure
      redirect_to :back if status_error == false
    end
  end

  def destroy
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      doc = if params[:divid].present?
        project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
      else
        project.docs.find_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
      end
      raise "There is no such document in the project." unless doc.present?

      span = params[:begin].present? ? {:begin => params[:begin].to_i, :end => params[:end].to_i} : nil

      doc.set_ascii_body if (params[:encoding] == 'ascii')
      denotations = doc.get_denotations(project, span)
      denotations.each{|d| d.destroy}

      respond_to do |format|
        format.html {redirect_to :back, status: :see_other, notice: "annotations deleted"}
        format.json {render status: :no_content}
      end
    end
  end

  private

  def set_access_control_headers
    allowed_origins = ['http://localhost', 'http://localhost:8000', 'http://bionlp.dbcls.jp', 'http://textae.pubannotation.org']
    origin = request.env['HTTP_ORIGIN']
    # if allowed_origins.include?(origin)
      headers['Access-Control-Allow-Origin'] = origin
      headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
      headers['Access-Control-Allow-Headers'] = 'Origin, Accept, Content-Type, X-Requested-With, X-CSRF-Token, X-Prototype-Version'
      headers['Access-Control-Allow-Credentials'] = 'true'
      headers['Access-Control-Max-Age'] = "1728000"
    # end
  end

end
