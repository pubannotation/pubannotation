require 'zip/zip'

class AnnotationsController < ApplicationController
  protect_from_forgery :except => [:create]
  before_filter :authenticate_user!, :except => [:index, :show, :annotations_index,:annotations]
  after_filter :set_access_control_headers
  include DenotationsHelper

  def index
    @project, notice = get_project(params[:project_id])

    if @project

      if (params[:pmdoc_id] || params[:pmcdoc_id] || params[:id] || (params[:sourcedb] && params[:sourceid]))
        sourcedb, sourceid, serial, id = get_docspec(params)
        @doc, notice = get_doc(sourcedb, sourceid, serial, @project, id)
        if @doc
          annotations = get_annotations_for_json(@project, @doc, :encoding => params[:encoding])
          @text = annotations[:text]
          @denotations = annotations[:denotations]
          @relations = annotations[:relations]
          @modifications = annotations[:modifications]
        end

      else
        if params[:delay].present?
          # delete ZIP file if params[:update]
          File.unlink(@project.annotations_zip_path) if params[:update].present?
          # Creaet ZIP file by delayed_job
          @project.delay.save_annotation_zip(:encoding => params[:encoding])
          redirect_to :back
        else
          # retrieve annotatons to all the documents
          # anncollection = @project.anncollection(params[:encoding])
          anncollection = Array.new
          if @project.docs.present?
            @project.docs.each do |doc|
              # puts "#{doc.sourceid}:#{doc.serial} <======="
              # anncollection.push (get_annotations(self, doc, :encoding => encoding))
              anncollection.push (get_annotations_for_json(@project, doc, :encoding => params[:encoding]))
            end
          end
        end
      end
    end

    respond_to do |format|
      if @project and @text

        format.html { flash[:notice] = notice }
        format.json { render :json => annotations, :callback => params[:callback] }
        format.ttl  {
          if @project.rdfwriter.empty?
            head :unprocessable_entity
          else
            render :text => get_conversion(annotations, @project.rdfwriter), :content_type => 'application/x-turtle'
          end
        }
        format.xml  {
          if @project.xmlwriter.empty?
            head :unprocessable_entity
          else
            render :text => get_conversion(annotations, @project.xmlwriter, serial), :content_type => 'application/xml;charset=urf-8'
          end
        }
      elsif anncollection && anncollection[0].class == Hash

        format.json {
          file_name = (@project)? @project.name + ".zip" : "annotations.zip"
          t = Tempfile.new("pubann-temp-filename-#{Time.now}")
          Zip::ZipOutputStream.open(t.path) do |z|
            anncollection.each do |ann|
              title = get_doc_info(ann[:target])
              title.sub!(/\.$/, '')
              title.gsub!(' ', '_')
              title += ".json" unless title.end_with?(".json")
              z.put_next_entry(title)
              z.print ann.to_json
            end
          end
          send_file t.path, :type => 'application/zip',
                            :disposition => 'attachment',
                            :filename => file_name
          t.close
        }
        format.ttl {
          ttl = ''
          header_length = 0
          anncollection.each_with_index do |ann, i|
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

      else
        format.html { flash[:notice] = notice }
        format.json { head :unprocessable_entity }
        format.ttl  { head :unprocessable_entity }
      end
    end

  end

  # annotations for doc without project
  def annotations_index
    sourcedb, sourceid, serial, id = get_docspec(params)
    @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, nil, id)
    if @doc
      @denotations = @doc.project_denotations
      annotations = get_annotations_for_json(nil, @doc, :encoding => params[:encoding])
    end

    respond_to do |format|
      format.html {}
      format.json { render :json => annotations, :callback => params[:callback] }
    end
  end

  def annotations
    sourcedb, sourceid, serial, id = get_docspec(params)
    params[:project_id] = params[:project] if params[:project].present?
    if params[:project_id].present?
      @project, flash[:notice] = get_project(params[:project_id])
      if @project
        @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, @project)
        @project_denotations = get_project_denotations([@project], @doc, params)
      end
    else
      @doc, flash[:notice] = get_doc(sourcedb, sourceid, serial, nil, id)
      if params[:projects].present?
        projects = Project.name_in(params[:projects].split(','))
      else
        projects = @doc.projects
      end
      @project_denotations = get_project_denotations(projects, @doc, params)
    end

    if @doc.present?
      @spans, @prev_text, @next_text = @doc.spans(params)
      annotations = get_annotations_for_json(@project, @doc, :spans => {:begin_pos => params[:begin], :end_pos => params[:end]}, :projects => params[:projects], :project_denotations => @project_denotations, doc_spans: @spans, params: params)

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
    project, notice = get_project(params[:project_id])

    if project
      sourcedb, sourceid, divno = get_docspec(params)
      divnos = divno.respond_to?(:each) ? divno : [divno]
      divs = divnos.collect{|no| get_doc(sourcedb, sourceid, no)[0]}
      divs = [] if divs[0].nil? || !project.docs.include?(divs[0])

      unless divs.empty?

        # get annotations
        annotations = if params[:annotations]
          params[:annotations].symbolize_keys
        elsif params[:text] and !params[:text].empty?
          {:text => params[:text], :denotations => params[:denotations], :relations => params[:relations], :modifications => params[:modifications]}
        else
          nil
        end

        if annotations
          fits = Shared.store_annotations(annotations, project, divs)
        else
          notice = t('controllers.annotations.create.no_annotation')
        end
      else
        notice = t('controllers.annotations.create.no_project_document', :project_id => params[:project_id], :sourcedb => params[:sourcedb], :sourceid => params[:sourceid])
      end
    end

    respond_to do |format|
      format.html {
        if doc and project
          redirect_to :back, notice: notice
        elsif project
          redirect_to project_path(project.name), notice: notice
        else
          redirect_to home_path, notice: notice
        end
      }

      format.json {
        if divs && !divs.empty? && project && annotations
          if fits.nil?
            render :json => {:status => :created}, :status => :created
          else
            render :json => {:status => :created, :fits => fits}, :status => :created
          end
        else
          render :json => {:status => :unprocessable_entity}, :status => :unprocessable_entity
        end
      }
    end

  end


  # POST /annotations
  # POST /annotations.json
  def generate
    project = Project.accessible(current_user).find_by_name(params[:project_id])

    if project
      doc, notice = get_doc(*get_docspec(params))
      if doc
        annotations = get_annotations(project, doc, :encoding => params[:encoding])
        annotations = gen_annotations(annotations, params[:annotation_server])
        notice      = Shared.save_annotations(annotations, project, doc)
      else
        notice = t('controllers.annotations.create.no_project_document', :project_id => params[:project_id], :sourcedb => params[:sourcedb], :sourceid => params[:sourceid])
      end
    end

    respond_to do |format|
      format.html {
        if doc and project
          redirect_to :back, notice: notice
        elsif project
          redirect_to project_path(project.name), notice: notice
        else
          redirect_to home_path, notice: notice
        end
      }

      format.json {
        if doc and project and annotations
          head :no_content, :content_type => ''
        else
          head :unprocessable_entity
        end
      }
    end
  end


  # DELETE /projects/:hid
  # DELETE /projects/:hid.json
  # def destroy
    # @project, notice = get_project(params[:project_id])
    # if @project
      # if (params[:pmdoc_id] || params[:pmcdoc_id])
        # sourcedb, sourceid, serial = get_docspec(params)
        # @doc, notice = get_doc(sourcedb, sourceid, serial, @project)
        # if @doc
          # annotations = get_annotations(@project, @doc, :encoding => params[:encoding])
        # end
      # end
    # end
    # @annotations.destroy
# 
    # respond_to do |format|
      # format.html { redirect_to projects_path, notice: t('controller.projects.destroy.deleted', :id => params[:id]) }
      # format.json { head :no_content }
    # end
  # end

  def destroy_all
    @project = get_project(params[:project_id])[0]
    sourcedb, sourceid, serial, id = get_docspec(params)
    @doc = get_doc(sourcedb, sourceid, serial, @project)[0]
    annotations_destroy_all_helper(@doc, @project)
    redirect_to :back
  end

  private

  def set_access_control_headers
    allowed_origins = ['http://localhost', 'http://localhost:8000', 'http://bionlp.dbcls.jp']
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
