class PmcdocsController < ApplicationController
  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    if params[:annset_id] and annset = Annset.find_by_name(params[:annset_id])
      @docs = annset.docs.where(:sourcedb => 'PMC', :serial => 0).uniq.paginate(:page => params[:page])
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
    redirect_to pmcdoc_divs_path(params[:id])
  end
end
