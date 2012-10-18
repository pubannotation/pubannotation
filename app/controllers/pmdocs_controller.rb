class PmdocsController < ApplicationController
  # GET /pmdocs
  # GET /pmdocs.json
  def index
    if params[:annset_id] and annset = Annset.find_by_name(params[:annset_id])
      @docs = annset.docs.uniq.keep_if{|d| d.sourcedb == 'PubMed' and d.serial == 0}.paginate(:page => params[:page])
#      @docs = annset.docs.where(:sourcedb => 'PubMed', :serial => 0).uniq.paginate(:page => params[:page])
    else
      @docs = Doc.where(:sourcedb => 'PubMed', :serial => 0).paginate(:page => params[:page])
    end

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
      @doc = get_pmdoc(params[:id]) 
      @doc.save if @doc
    end

    @text = @doc.body
    if (params[:encoding] == 'ascii')
      asciitext = get_ascii_text(@text)
      @text = asciitext
    end

    @annsets = @doc.annsets.uniq

    respond_to do |format|
      if @doc
        format.html { render 'docs/show' } # show.html.erb
        format.json { render json: @doc }
      else 
        format.html { redirect_to pmdocs_url}
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end
end
