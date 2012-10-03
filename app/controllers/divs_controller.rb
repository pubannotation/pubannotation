class DivsController < ApplicationController
  # GET /pmcdocs/:pmcid/divs
  # GET /pmcdocs/:pmcid/divs.json
  def index
    @docs = Doc.find_all_by_sourcedb_and_sourceid('PMC', params[:pmcdoc_id])

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
    end
  end

  # GET /pmcdocs/:pmcid/divs/:divid
  # GET /pmcdocs/:pmcid/divs/:divid.json
  def show
    @doc = Doc.find_by_sourcedb_and_sourceid_and_serial('PMC', params[:pmcdoc_id], params[:id])
    @annsets = @doc.annsets.uniq

    respond_to do |format|
      if @doc
        format.html { render 'docs/show' } # show.html.erb
        format.json { render json: @doc }
      else 
        format.html { redirect_to pmcdocs_url}
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /pmcdocs/:pmcid/divs/new
  # GET /pmcdocs/:pmcid/divs/new.json
  def new
    @doc = Doc.new
    @doc.sourcedb = 'PMC'
    @doc.sourceid = params[:pmcdoc_id]
    @doc.source   = 'http://www.ncbi.nlm.nih.gov/pmc/' + params[:pmcdoc_id]

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @doc }
    end
  end

  # GET /pmcdocs/:pmcid/divs/:divid/edit
  def edit
    @doc = Doc.find(params[:id])
  end

  # POST /pmcdocs/:pmcid/divs
  # POST /pmcdocs/:pmcid/divs.json
  def create

    @doc = Doc.new(params[:doc])
    @doc.sourcedb = 'PMC'
    @doc.sourceid = params[:pmcdoc_id]
    @doc.source = 'http://www.ncbi.nlm.nih.gov/pmc/' + @doc.sourceid
    @doc.serial   = params[:div_id]
    @doc.section  = params[:section]
    @doc.body     = params[:text]

    respond_to do |format|
      if @doc.save
        format.html { redirect_to @doc, notice: 'Doc was successfully created.' }
        format.json { render json: @doc, status: :created, location: @doc }
      else
        format.html { render action: "new" }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /docs/1
  # PUT /docs/1.json
  def update
    @doc = Doc.find(params[:id])

    respond_to do |format|
      if @doc.update_attributes(params[:doc])
        format.html { redirect_to @doc, notice: 'Doc was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @doc.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /docs/1
  # DELETE /docs/1.json
  def destroy
    @doc = Doc.find(params[:id])
    @doc.destroy

    respond_to do |format|
      format.html { redirect_to docs_url }
      format.json { head :no_content }
    end
  end
end
