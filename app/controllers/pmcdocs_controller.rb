class PmcdocsController < ApplicationController
  # GET /pmcdocs
  # GET /pmcdocs.json
  def index
    @docs = Doc.find_all_by_sourcedb_and_serial('PMC', 0)

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
