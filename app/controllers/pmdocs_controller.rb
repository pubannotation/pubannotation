class PmdocsController < ApplicationController
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    @docs = Doc.find_all_by_sourcedb('PubMed')

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
    end
  end

  # GET /pmdocs/:pmid
  # GET /pmdocs/:pmid.json
  def show
    @doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:id])

    if !@doc
      doc = get_pmdoc(sourceid) 
      @doc.save if @doc
    end

    respond_to do |format|
      if @doc
        format.html # show.html.erb
        format.json { render json: @doc }
      else 
        format.html { redirect_to pmdocs_url}
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end
end
