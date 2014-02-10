require 'zip/zip'

class AnnotationsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  after_filter :set_access_control_headers

  def index
    @project, notice = get_project(params[:project_id])
    if @project

      if (params[:pmdoc_id] || params[:pmcdoc_id] || params[:doc_id])
        sourcedb, sourceid, serial, id = get_docspec(params)
        @doc, notice = get_doc(sourcedb, sourceid, serial, @project, id)

        if @doc
          annotations = get_annotations(@project, @doc, :encoding => params[:encoding])
          @text = annotations[:text]
          @denotations = annotations[:denotations]
          @instances = annotations[:instances]
          @relations = annotations[:relations]
          @modifications = annotations[:modifications]
        end

      else
        if params[:delay].present?
          # Creaet ZIP file by delayed_job
          @project.delay.save_annotation_zip(:encoding => params[:encoding])
          redirect_to :back
        else
          # retrieve annotatons to all the documents
          anncollection = @project.anncollection(params[:encoding])
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
              title = "%s-%s-%02d-%s" % [ann[:source_db], ann[:source_id], ann[:division_id], ann[:section]]
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
          anncollection.each_with_index do |ann, i|
            if i == 0 then ttl = get_conversion(ann, @project.rdfwriter).split("\n")[0..8].join("\n") end
            ttl += "\n" + get_conversion(ann, @project.rdfwriter).split("\n")[9..-1].join("\n")
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


  # POST /annotations
  # POST /annotations.json
  def create
    if params[:annotation_server] or (params[:annotations])

      project, notice = get_project(params[:project_id])
      if project
        sourcedb, sourceid, serial, id = get_docspec(params)
        doc, notice = get_doc(sourcedb, sourceid, serial, project, id)
        if doc
          if params[:annotation_server]
            annotations = get_annotations(project, doc, :encoding => params[:encoding])

            # options = [:db_name => params[:dictionary], :tax_ids => params[:tax_ids].split(/\s+/)]
            # options = {:tax_ids => params[:tax_ids].split(/\s+/).collect {|id| id.to_i}}
            # options = {:dics => params[:dics].split(/\s*,\s*/)}
            options = nil
            annotations = gen_annotations(annotations, params[:annotation_server], options)
          else
            annotations = JSON.parse params[:annotations], :symbolize_names => true
          end
          notice = save_annotations(annotations, project, doc)
        else
          notice = t('controller.annotations.create.does_not_include', :project_id => params[:project_id], :sourceid => sourceid)
        end
      end
    else
      notice = t('controller.annotations.create.no_annotation')
    end

    respond_to do |format|
      format.html {
        if doc and project
          if doc.sourcedb == 'PubMed'
            redirect_to project_pmdoc_path(project.name, doc.sourceid), notice: notice
          elsif doc.sourcedb == 'PMC'
            redirect_to project_pmcdoc_div_path(project.name, doc.sourceid, doc.serial), notice: notice
          else
            redirect_to project_doc_path(project.name, doc.id), notice: notice
          end
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
    sourcedb, sourceid, serial = get_docspec(params)
    @doc = get_doc(sourcedb, sourceid, serial, @project)[0]
    if @doc
      annotations = @doc.denotations.where("project_id = ?", @project.id)
      
      ActiveRecord::Base.transaction do
        begin
          annotations.destroy_all
        rescue => e
          flash[:notice] = e
        end
      end
    end
    redirect_to :back
  end

  private

  def set_access_control_headers
    allowed_origins = ["http://localhost", "http://bionlp.dbcls.jp"]
    origin = request.env['HTTP_ORIGIN']
    if allowed_origins.include?(origin)
      headers['Access-Control-Allow-Origin'] = origin
      headers['Access-Control-Expose-Headers'] = 'ETag'
      headers['Access-Control-Allow-Methods'] = "GET, POST, OPTIONS"
      headers['Access-Control-Allow-Headers'] = "Authorization, X-Requested-With"
      headers['Access-Control-Allow-Credentials'] = "true"
      headers['Access-Control-Max-Age'] = "1728000"
    end
  end

end
