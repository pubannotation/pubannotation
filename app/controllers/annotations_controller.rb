class AnnotationsController < ApplicationController
  def index
    @annset = Annset.find_by_name(params[:annset_id])

    if @annset
      sourcedb, sourceid, serial = get_docspec(params)
      @text = get_doctext(sourcedb, sourceid, serial)

      if @text
        @catanns = get_hcatanns(@annset.name, sourcedb, sourceid, serial)
        @insanns = get_hinsanns(@annset.name, sourcedb, sourceid, serial)
        @relanns = get_hrelanns(@annset.name, sourcedb, sourceid, serial)
        @modanns = get_hmodanns(@annset.name, sourcedb, sourceid, serial)

        if (params[:encoding] == 'ascii')
          asciitext = get_ascii_text (@text)
          @catanns = adjust_catanns(@catanns, @text, asciitext)
          @text = asciitext
        end

        if (params[:discontinuous_annotation] == 'bag')
          # TODO: convert to hash representation
          @catanns, @relanns = bag_catanns(@catanns, @relanns)
        end
      else
        notice = "The document, #{sourcedb}:#{sourceid}, does not exist."
      end
    else
      notice = "The annotation set, #{params[:annset_id]}, does not exist."
    end

    respond_to do |format|
      if @annset
        if @text
          format.html # index.html.erb
          format.json {
            standoff = Hash.new
            if sourcedb == 'PudMed'
              standoff[:pmdoc_id] = sourceid
            elsif sourcedb == 'PMC'
              standoff[:pmcdoc_id] = sourceid
              standoff[:div_id] = serial
            end
            standoff[:text] = @text
            standoff[:catanns] = @catanns if @catanns
            standoff[:insanns] = @insanns if @insanns
            standoff[:relanns] = @relanns if @relanns
            standoff[:modanns] = @modanns if @modanns

            render :json => standoff, :callback => params[:callback]
          }
          format.ttl {
            @docuri = get_docuri(sourcedb, sourceid)
            @texturi = get_texturi(sourcedb, sourceid, serial)
            @catidx = Hash.new
            @catanns.each {|ca| @catidx[ca.id] = ca.category}
            render :file => "annotations/index.ttl", :type => :erb
          }
        else
          format.html { flash[:notice] = notice }
          format.json { render json: {}, status: :unprocessable_entity }
        end
      else
        format.html { flash[:notice] = notice }
        format.json { render json: {}, status: :unprocessable_entity }
      end
    end
  end


  # POST /annotations
  # POST /annotations.json
  def create
    annset = Annset.find_by_name(params[:annset_id])

    if annset
      sourcedb, sourceid, serial = get_docspec(params)
      doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if doc and doc.annsets.include?(annset)
        catanns = params[:catanns]
        catanns.each do |a|
          a[:span][:begin] = a[:span][:begin].to_i
          a[:span][:end]   = a[:span][:end].to_i
        end
        catanns, message = adjust_catanns(catanns, params[:text], doc.body)
        if catanns
          catanns_old = doc.catanns.where("annset_id = ?", annset.id)
          catanns_old.destroy_all

          save_hcatanns(catanns, annset, doc)
          save_hinsanns(params[:insanns], annset, doc) if params[:insanns]
          save_hrelanns(params[:relanns], annset, doc) if params[:relanns]
          save_hmodanns(params[:modanns], annset, doc) if params[:modanns]
        else
          notice = message
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not include the document, PubMed:#{sourceid}."
      end
    else
      notice = "The annotation set, #{params[:annset_id]}, does not exist."
    end

    respond_to do |format|
      if doc and annset
        format.html {redirect_to pmdoc_path(@doc.name), notice: 'Catanns were successfully created.'}
        format.json {
          res = {"result"=>"true"}
          render :json => res
        }
      else
        format.html { redirect_to home_path, notice: notice }
        format.json { head :no_content }
      end
    end

  end

end
