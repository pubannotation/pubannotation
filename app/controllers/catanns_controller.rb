class CatannsController < ApplicationController
  # GET /catanns
  # GET /catanns.json
  def index
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
      serial    = 0
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
      serial   = params[:div_id]
    end

    @catanns = get_catanns_simple(params[:annset_id], sourcedb, sourceid, serial)
    @text = get_doctext(sourcedb, sourceid, serial)

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        @standoff = {:text => @text, :catanns => @catanns}
        render :json => @standoff, :callback => params[:callback]
      }
    end
  end

  # GET /catanns/1
  # GET /catanns/1.json
  def show
    @catann = Catann.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @catann }
    end
  end

  # GET /catanns/new
  # GET /catanns/new.json
  def new
    @catann = Catann.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @catann }
    end
  end

  # GET /catanns/1/edit
  def edit
    @catann = Catann.find(params[:id])
  end

  # POST /catanns
  # POST /catanns.json
  def create
    if params[:pmdoc_id]
      sourcedb = 'PubMed'
      sourceid = params[:pmdoc_id]
      serial   = 0
    end

    if params[:pmcdoc_id]
      sourcedb = 'PMC'
      sourceid = params[:pmcdoc_id]
      serial   = params[:div_id]
    end

    doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
    if !doc and sourcedb == 'PubMed'
      doc = get_pmdoc(sourceid) 
      doc.save if doc
    end

    annset = Annset.find_by_name(params[:annset_id])
    
    if doc and annset
    
      ## find the differences of the text
      position_map = Hash.new
      numchar, numdiff = 0, 0
      Diff::LCS.sdiff(params[:text], doc.body) do |h|
        position_map[h.old_position] = h.new_position
        numchar += 1
        numdiff += 1 if h.old_position != h.new_position
      end
     
#      if (params[:text] != @doc.body)
#      if (numdiff.to_f / numchar) > 0.5
#        return render :text => "text mismatch! (#{numdiff.to_f/numchar})\n#{@doc.body}\n---\n#{params[:text]}"
#      end

      catanns = doc.catanns.where("annset_id = ?", annset.id)
      catanns.destroy_all

      params[:catanns].each do |a|
        ca           = Catann.new(a)
        ca.begin     = position_map[ca.begin]
        ca.end       = position_map[ca.end]
        ca.doc_id    = doc.id
        ca.annset_id = annset.id
        ca.save
      end
      
    end

    respond_to do |format|
      if doc and annset
        format.html {redirect_to pmdoc_path(@doc.name), notice: 'Catanns were successfully created.'}
        format.json {
          res = {"result"=>"true"}
          render :json => res
        }
      else
        format.html { redirect_to catanns_url }
        format.json { head :no_content }
      end
    end

  end

  # PUT /catanns/1
  # PUT /catanns/1.json
  def update
    @catann = Catann.find(params[:id])

    respond_to do |format|
      if @catann.update_attributes(params[:catann])
        format.html { redirect_to @catann, notice: 'Catann was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @catann.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /catanns/1
  # DELETE /catanns/1.json
  def destroy
    @catann = Catann.find(params[:id])
    @catann.destroy

    respond_to do |format|
      format.html { redirect_to catanns_url }
      format.json { head :no_content }
    end
  end
end
