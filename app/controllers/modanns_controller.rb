class ModannsController < ApplicationController
  # GET /modanns
  # GET /modanns.json
  def index
    sourcedb, sourceid, serial = get_docspec(params)

    @modanns = get_modanns_simple(params[:annset_id], sourcedb, sourceid, serial)

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
    sourcedb, sourceid, serial = get_docspec(params)

    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    annset = Annset.find_by_name(params[:annset_id])
    
    if doc and annset
      params[:modanns].each do |a|
        ma           = Modann.new

        ma.modtype   = a[:modtype]
        ma.modobj    = case a[:modobj]
          when /^R/ then doc.relanns.find_by_annset_id_and_hid(annset.id, a[:modobj])
          else           doc.insanns.find_by_annset_id_and_hid(annset.id, a[:modobj])
        end

        ma.hid       = a[:hid]
        ma.annset_id = annset.id
        ma.save
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
