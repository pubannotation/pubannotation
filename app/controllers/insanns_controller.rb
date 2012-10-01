class InsannsController < ApplicationController
  # GET /insanns
  # GET /insanns.json
  def index
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
    end

    @insanns = get_insanns_simple(sourcedb, sourceid, params[:annset_id])

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        @standoff = {:insanns => @insanns}
        render :json => @standoff, :callback => params[:callback]
      }
    end
  end

  # GET /insanns/1
  # GET /insanns/1.json
  def show
    @insann = Insann.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @insann }
    end
  end

  # GET /insanns/new
  # GET /insanns/new.json
  def new
    @insann = Insann.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @insann }
    end
  end

  # GET /insanns/1/edit
  def edit
    @insann = Insann.find(params[:id])
  end

  # POST /insanns
  # POST /insanns.json
  def create
    doc = Doc.find_by_sourceid(params[:pmdoc_id])
    annset = Annset.find_by_name(params[:annset_id])
    
    if doc and annset
      params[:insanns].each do |a|
        ia           = Insann.new

        ia.instype   = a[:instype]
        ia.insobj    = Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:insobj])

        ia.hid       = a[:hid]
        ia.annset_id = annset.id
        ia.save
      end
    end

    respond_to do |format|
      format.html {redirect_to pmdoc_path(@doc.name), notice: 'Insanns created successfully.'}
      format.json {
        res = {"result"=>"true"}
        render :json => res
      }
    end
  end

  # PUT /insanns/1
  # PUT /insanns/1.json
  def update
    @insann = Insann.find(params[:id])

    respond_to do |format|
      if @insann.update_attributes(params[:insann])
        format.html { redirect_to @insann, notice: 'Insann was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @insann.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /insanns/1
  # DELETE /insanns/1.json
  def destroy
    @insann = Insann.find(params[:id])
    @insann.destroy

    respond_to do |format|
      format.html { redirect_to insanns_url }
      format.json { head :no_content }
    end
  end
end
