class RelannsController < ApplicationController
  # GET /relanns
  # GET /relanns.json
  def index
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
    end

    @relanns = get_relanns_simple(sourcedb, sourceid, params[:annset_id])

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        @standoff = {:relanns => @relanns}
        render :json => @standoff, :callback => params[:callback]
      }
    end
  end

  # GET /relanns/1
  # GET /relanns/1.json
  def show
    @relann = Relann.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @relann }
    end
  end

  # GET /relanns/new
  # GET /relanns/new.json
  def new
    @relann = Relann.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @relann }
    end
  end

  # GET /relanns/1/edit
  def edit
    @relann = Relann.find(params[:id])
  end

  # POST /relanns
  # POST /relanns.json
  def create
    doc = Doc.find_by_sourceid(params[:pmdoc_id])
    annset = Annset.find_by_name(params[:annset_id])
    
    @relann = []

    if doc and annset

      params[:relanns].each do |a|
        ra           = Relann.new
        ra.hid       = a[:hid]

        ra.subject   = case a[:subject]
          when /^T/ then Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:subject])
          else doc.insanns.find_by_annset_id_and_hid(annset.id, a[:subject])
        end

        ra.object    = case a[:object]
          when /^T/ then Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:object])
          else doc.insanns.find_by_annset_id_and_hid(annset.id, a[:object])
        end

        ra.relation  = a[:relation]
        ra.annset_id = annset.id
        ra.save
        @relann      = ra
      end
      
    end

    respond_to do |format|
      format.html {redirect_to pmdoc_path(doc.name), notice: 'Relanns created successfully.'}
      format.json {
        res = {"result"=>"true"}
        render :json => res
      }
    end
  end

  # PUT /relanns/1
  # PUT /relanns/1.json
  def update
    @relann = Relann.find(params[:id])

    respond_to do |format|
      if @relann.update_attributes(params[:relann])
        format.html { redirect_to @relann, notice: 'Relann was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @relann.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /relanns/1
  # DELETE /relanns/1.json
  def destroy
    @relann = Relann.find(params[:id])
    @relann.destroy

    respond_to do |format|
      format.html { redirect_to relanns_url }
      format.json { head :no_content }
    end
  end
end
