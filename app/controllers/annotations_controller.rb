class AnnotationsController < ApplicationController
  def index
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
    end

    @text = get_doctext(sourcedb, sourceid)
    @catanns = get_catanns_simple(sourcedb, sourceid, params[:annset_id])
    @insanns = get_insanns_simple(sourcedb, sourceid, params[:annset_id])
    @relanns = get_relanns_simple(sourcedb, sourceid, params[:annset_id])

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        @standoff = {:text => @text, :catanns => @catanns, :insanns => @insanns, :relanns => @relanns}
        render :json => @standoff, :callback => params[:callback]
      }
    end
  end

  def create
  end
end
