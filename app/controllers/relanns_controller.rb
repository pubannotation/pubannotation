class RelannsController < ApplicationController
  # GET /relanns
  # GET /relanns.json
  def index
    sourcedb, sourceid, serial = get_docspec(params)

    @relanns = get_relanns_simple(params[:annset_id], sourcedb, sourceid, serial)

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
    sourcedb, sourceid, serial = get_docspec(params)

    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    annset = Annset.find_by_name(params[:annset_id])
    
    if doc and annset
      params[:relanns].each do |a|
        ra           = Relann.new

        ra.relsub    = case a[:relsub]
          when /^T/ then Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:relsub])
          else           doc.insanns.find_by_annset_id_and_hid(annset.id, a[:relsub])
        end
        ra.relobj    = case a[:relobj]
          when /^T/ then Catann.find_by_doc_id_and_annset_id_and_hid(doc.id, annset.id, a[:relobj])
          else           doc.insanns.find_by_annset_id_and_hid(annset.id, a[:relobj])
        end
        ra.reltype   = a[:reltype]

        ra.hid       = a[:hid]
        ra.annset_id = annset.id
        ra.save
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
