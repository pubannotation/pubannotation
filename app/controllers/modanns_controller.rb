class ModannsController < ApplicationController
  # GET /modanns
  # GET /modanns.json
  def index
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
    end

    @modanns = get_modanns_simple(sourcedb, sourceid, params[:annset_id])

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        @standoff = {:modanns => @modanns}
        render :json => @standoff, :callback => params[:callback]
      }
    end
  end

  # GET /modanns/1
  # GET /modanns/1.json
  def show
    @modann = Modann.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @modann }
    end
  end

  # GET /modanns/new
  # GET /modanns/new.json
  def new
    @modann = Modann.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @modann }
    end
  end

  # GET /modanns/1/edit
  def edit
    @modann = Modann.find(params[:id])
  end

  # POST /modanns
  # POST /modanns.json
  def create
    doc = Doc.find_by_sourceid(params[:pmdoc_id])
    annset = Annset.find_by_name(params[:annset_id])
    
    @modann = []

    if doc and annset
      params[:modanns].each do |a|
        ma           = Modann.new
        ma.hid       = a[:hid]
        ma.modtype   = a[:objtype]
        if a[:modobj] =~ /^R/
          obj = doc.relann.find_by_annset_id_and_hid(annset.id, a[:modobj])
        else
          obj = doc.insann.find_by_annset_id_and_hid(annset.id, a[:modobj])
        end
        ma.modobj    = obj
        ma.annset_id = annset.id
        ma.save
        @modann = ma
      end
    end

    respond_to do |format|
      format.html {redirect_to pmdoc_path(@doc.name), notice: 'Modanns created successfully.'}
      format.json {
        res = {"result"=>"true"}
        render :json => res
      }
    end
  end

  # PUT /modanns/1
  # PUT /modanns/1.json
  def update
    @modann = Modann.find(params[:id])

    respond_to do |format|
      if @modann.update_attributes(params[:modann])
        format.html { redirect_to @modann, notice: 'Modann was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @modann.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /modanns/1
  # DELETE /modanns/1.json
  def destroy
    @modann = Modann.find(params[:id])
    @modann.destroy

    respond_to do |format|
      format.html { redirect_to modanns_url }
      format.json { head :no_content }
    end
  end
end
