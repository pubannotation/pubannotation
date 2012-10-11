class AnnotationsController < ApplicationController
  def index
    sourcedb, sourceid, serial = get_docspec(params)

    @text = get_doctext(sourcedb, sourceid, serial)
    @catanns = get_catanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @insanns = get_insanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @relanns = get_relanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @modanns = get_modanns_simple(params[:annset_id], sourcedb, sourceid, serial)

    if (params[:encoding] == 'ascii')
      asciitext = get_ascii_text(@text)
      @catanns = adjust_catanns(@catanns, @text, asciitext)
      @text = asciitext
    end

    unless (params[:discontinuous_annotation] == 'chain')
      @catanns, @relanns = bag_catanns(@catanns, @relanns)
    end


    respond_to do |format|
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
        standoff[:catanns] = @catanns
        standoff[:insanns] = @insanns
        standoff[:relanns] = @relanns
        standoff[:modanns] = @modanns

        render :json => standoff, :callback => params[:callback]
      }
      format.ttl {
        @docuri = get_docuri(sourcedb, sourceid)
        @texturi = get_texturi(sourcedb, sourceid, serial)
        @catidx = Hash.new
        @catanns.each {|ca| @catidx[ca.id] = ca.category}
        render :file => "annotations/index.ttl", :type => :erb
      }

    end
  end

  def create
  end
end
