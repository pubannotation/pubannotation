require 'zip/zip'

class AnnotationsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :except => [:doc_annotations_index, :div_annotations_index, :project_doc_annotations_index, :project_div_annotations_index, :doc_annotations_visualize, :div_annotations_visualize, :project_annotations_zip]
  include DenotationsHelper

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

        project = if params[:project].present?
          params[:project].split(',').uniq.map{|project_name| Project.accessible(current_user).find_by_name(project_name)}
        else
          nil
        end

        project = project[0] if project.present? && project.length == 1
        @annotations = @doc.hannotations(project, @span)
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
    puts "here <==============="

    begin
      @project = Project.find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      unless @project.public?
        authenticate_user!
        raise "There is no such project in your access." unless @project.accessible?(current_user)
      end

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
      @project = Project.find_by_name(params[:project_id])
      raise "There is no such project." unless @project.present?

      unless @project.public?
        authenticate_user!
        raise "There is no such project in your access." unless @project.accessible?(current_user)
      end

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

  # POST /annotations
  # POST /annotations.json
  def create
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

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

      options = {}
      options[:mode] = :addition if params[:mode] == 'addition' || params[:mode] == 'add'
      options[:prefix] = params[:prefix] if params[:prefix].present?

      if params[:divid].present?
        doc = project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        unless doc.present?
          project.add_doc(params[:sourcedb], params[:sourceid])
          doc = project.docs.find_by_sourcedb_and_sourceid_and_serial(params[:sourcedb], params[:sourceid], params[:divid])
        end
        raise "Could not add the document in the project." unless doc.present?
      else
        divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        unless divs.present?
          project.add_doc(params[:sourcedb], params[:sourceid])
          divs = project.docs.find_all_by_sourcedb_and_sourceid(params[:sourcedb], params[:sourceid])
        end
        raise "Could not add the document in the project." unless divs.present?

        if divs.length == 1
          doc = divs[0]
        else
          project.notices.create({method: "annotations upload: #{params[:sourcedb]}:#{params[:sourceid]}"})
          project.delay.store_annotations(annotations, divs, {mode: mode, delayed: true})
          result = {message: "The task, 'annotations upload: #{params[:sourcedb]}:#{params[:sourceid]}', created."}
          respond_to do |format|
            format.html {redirect_to index_project_sourcedb_sourceid_divs_docs_path(project.name, params[:sourcedb], params[:sourceid])}
            format.json {render json: result}
          end
          return
        end
      end

      result = project.save_annotations(annotations, doc, options)
      notice = "annotations"

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {render json: result, status: :created}
      end

    rescue ArgumentError => e
      respond_to do |format|
        format.html {redirect_to (project.present? ? project_path(project.name) : home_path), notice: e.message}
        format.json {render :json => {error: e.message}, :status => :unprocessable_entity}
      end
    end
  end

  def obtain
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

      annotator = if params[:annotator].present?
        Annotator.find(params[:annotator])
      else
        Annotator.new({abbrev:params[:abbrev], url:params[:url], method:params[:method], params:{"text"=>"_text_", "sourcedb"=>"_sourcedb_", "sourceid"=>"_sourceid_"}})
      end

      options = {}
      options[:mode] = :addition if params[:mode] == 'addition' || params[:mode] == 'add'

      project.obtain_annotations(doc, annotator, options)
      notice = "annotations were successfully obtained."

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render status: :service_unavailable}
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

      options = {}
      options[:mode] = :addition if params[:mode] == 'addition' || params[:mode] == 'add'
      options[:prefix] = params[:prefix] if params[:prefix].present?
      options[:method] = params[:method] if params[:method].present?

      project.obtain_annotations0(doc, params[:annotation_server], options)
      notice = "annotations are successfully obtained."

      respond_to do |format|
        format.html {redirect_to :back, notice: notice}
        format.json {}
      end
    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {render status: :service_unavailable}
      end
    end
  end

  def create_from_zip
    begin
      project = if current_user.root? == true
        Project.find_by_name(params[:project_id])
      else
        Project.editable(current_user).find_by_name(params[:project_id])
      end

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
    rescue => e
      respond_to do |format|
        format.html {redirect_to :back, notice: e.message}
        format.json {}
      end
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

  def project_annotations_rdf
    begin
      project = Project.accessible(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_rdf_system_path)
        # redirect_to "/annotations/#{project.annotations_rdf_file_name}"
        redirect_to project.annotations_rdf_path
      else
        raise "annotation rdf file does not exist."
      end
    rescue => e
      render_status_error(:not_found)
    end
  end

  def delete_project_annotations_rdf
    begin
      status_error = false
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project." unless project.present?

      if File.exist?(project.annotations_rdf_system_path)
        if project.user == current_user 
          File.unlink(project.annotations_rdf_system_path)
          flash[:notice] = t('views.shared.rdf.deleted')
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


  def create_project_annotations_rdf
    begin
      project = Project.editable(current_user).find_by_name(params[:project_id])
      raise "There is no such project in your management." unless project.present?

      project.notices.create({method: "create annotations rdf"})
      # project.delay.create_annotations_rdf(params[:encoding])
      ttl = project.delay.create_annotations_rdf(params[:encoding])
      # render :text => ttl, :content_type => 'application/x-turtle', :filename => project.name
    rescue => e
      flash[:notice] = notice
    end
    redirect_to :back
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

end
