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
      format.html { flash[:notice] = notice }

      format.json {
        if @annset and @text
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
        else
          head :unprocessable_entity
        end
      }

      format.ttl {
        if @annset and @text
          @docuri = get_docuri(sourcedb, sourceid)
          @texturi = get_texturi(sourcedb, sourceid, serial)
          @catidx = Hash.new
          @catanns.each {|ca| @catidx[ca.id] = ca.category}
          render :file => "annotations/index.ttl", :type => :erb
        else
          head :unprocessable_entity
        end
      }

      format.js { head :no_content }
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
        if params[:catanns] and !params[:catanns].empty?
          catanns, notice = clean_hcatanns(params[:catanns])
          catanns, notice = adjust_catanns(catanns, params[:text], doc.body) if catanns
          if catanns
            catanns_old = doc.catanns.where("annset_id = ?", annset.id)
            catanns_old.destroy_all
          
            save_hcatanns(catanns, annset, doc)

            if params[:insanns] and !params[:insanns].empty?
              insanns = params[:insanns]
              insanns = insanns.values if insanns.respond_to?(:values)
              save_hinsanns(insanns, annset, doc)
            end

            if params[:relanns] and !params[:relanns].empty?
              relanns = params[:relanns]
              relanns = relanns.values if relanns.respond_to?(:values)
              save_hrelanns(relanns, annset, doc)
            end

            if params[:modanns] and !params[:modanns].empty?
              modanns = params[:modanns]
              modanns = modanns.values if modanns.respond_to?(:values)
              save_hmodanns(modanns, annset, doc)
            end

            notice = 'Annotations were successfully created/updated.'
          end
        else
          catanns_old = doc.catanns.where("annset_id = ?", annset.id)
          catanns_old.destroy_all
          notice = 'Annotations were all deleted.'
          catanns = true
        end
      else
        notice = "The annotation set, #{params[:annset_id]}, does not include the document, PubMed:#{sourceid}."
      end
    else
      notice = "The annotation set, #{params[:annset_id]}, does not exist."
    end

    respond_to do |format|
      format.html {
        if doc and annset
          redirect_to annset_pmdoc_path(annset.name, doc.name), notice: notice
        elsif annset
          redirect_to annset_path(annset.name), notice: notice
        else
          redirect_to home_path(annset.name), notice: notice
        end
      }

      format.json {
        if doc and annset and catanns
          head :no_content
        else
          head :unprocessable_entity
        end
      }
    end

  end

end
