class AnnotationsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]
  after_filter :set_access_control_headers

  def index
    @annset, notice = get_annset(params[:annset_id])
    if @annset
      sourcedb, sourceid, serial = get_docspec(params)
      @doc, notice = get_doc(sourcedb, sourceid, serial, @annset)
      if @doc
        annotations = get_annotations(@annset, @doc)
        @text = annotations[:text]
        @catanns = annotations[:catanns]
        @insanns = annotations[:insanns]
        @relanns = annotations[:relanns]
        @modanns = annotations[:modanns]

        if (params[:encoding] == 'ascii')
          asciitext = get_ascii_text (@text)
          @catanns = adjust_catanns(@catanns, @text, asciitext)
          @text = asciitext
        end

        if (params[:discontinuous_annotation] == 'bag')
          # TODO: convert to hash representation
          @catanns, @relanns = bag_catanns(@catanns, @relanns)
        end
      end
    end

    respond_to do |format|
      if @annset and @text
        format.html { flash[:notice] = notice }
        format.json { render :json => annotations, :callback => params[:callback] }
        format.ttl  {
          if @annset.rdfwriter.empty?
            head :unprocessable_entity
          else
            render :text => get_conversion(annotations, @annset.rdfwriter, serial), :content_type => 'application/x-turtle'
          end
        }
        format.xml  {
          if @annset.xmlwriter.empty?
            head :unprocessable_entity
          else
            render :text => get_conversion(annotations, @annset.xmlwriter, serial), :content_type => 'application/xml;charset=urf-8'
          end
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

      annset, notice = get_annset(params[:annset_id])
      if annset
        sourcedb, sourceid, serial = get_docspec(params)
        doc, notice = get_doc(sourcedb, sourceid, serial, annset)
        if doc
          if params[:annotation_server]
            annotations = get_annotations(annset, doc)
            annotations = gen_annotations(annotations, params[:annotation_server])
          else
            annotations = JSON.parse params[:annotations], :symbolize_names => true
          end

          notice = save_annotations(annotations, annset, doc)
        else
          notice = "The annotation set, #{params[:annset_id]}, does not include the document, PubMed:#{sourceid}."
        end
      end
    else
      notice = "No annotation found in the submission."
    end

    respond_to do |format|
      format.html {
        if doc and annset
          redirect_to annset_pmdoc_path(annset.name, doc.sourceid), notice: notice if doc.sourcedb == 'PubMed'
          redirect_to annset_pmcdoc_div_path(annset.name, doc.sourceid, doc.serial), notice: notice if doc.sourcedb == 'PMC'
        elsif annset
          redirect_to annset_path(annset.name), notice: notice
        else
          redirect_to home_path, notice: notice
        end
      }

      format.json {
        if doc and annset and annotations
          head :no_content, :content_type => ''
        else
          head :unprocessable_entity
        end
      }
    end

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
