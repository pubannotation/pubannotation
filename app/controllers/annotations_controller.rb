class AnnotationsController < ApplicationController
  def index
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
      serial    = 0
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
      serial   = params[:div_id]
    end

    @text = get_doctext(sourcedb, sourceid, serial)
    @catanns = get_catanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @insanns = get_insanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @relanns = get_relanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @modanns = get_modanns_simple(params[:annset_id], sourcedb, sourceid, serial)

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
    end
  end

  def create
  end
end
