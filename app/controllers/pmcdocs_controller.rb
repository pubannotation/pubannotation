class PmcdocsController < ApplicationController
  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:annset_id] and @annset = Annset.find_by_name(params[:annset_id])
      @docs = @annset.docs.where(:sourcedb => 'PMC', :serial => 0).uniq.paginate(:page => params[:page])
    else
      @docs = Doc.where(:sourcedb => 'PMC', :serial => 0).paginate(:page => params[:page])
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
    end
  end

  # GET /pmcdocs/:pmcdoc_id
  # GET /pmcdocs/:pmcdoc_id.json
  def show
    @doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PMC', params[:id], 0)
    if @doc
      if params[:annset_id]
        redirect_to annset_pmcdoc_divs_path(params[:annset_id], params[:id]), :notice => notice
      else
        redirect_to pmcdoc_divs_path(params[:id]), :notice => notice
      end
    else
      if params[:annset_id]
        redirect_to annset_pmcdocs_path(params[:annset_id]), :notice => "No such document in the current annotation set."
      else
        @doc = get_pmcdoc(params[:id])
        if @doc
          redirect_to pmcdoc_divs_path(params[:id]), :notice => "The proxy document is successfully created."
        else
          redirect_to pmcdocs_path, :notice => "The proxy document creation for PMC:#{params[:id]} was not successful."
        end
      end
    end
  end
end
