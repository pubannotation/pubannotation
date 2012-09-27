class AnnsetsController < ApplicationController
  # GET /annsets
  # GET /annsets.json
  def index
    if params[:pmdoc_id]
      @doc = Doc.find_by_sourcedb_and_sourceid('PubMed', params[:pmdoc_id])
      if @doc
        @annsets = @doc.annsets.uniq
      else
        @annsets = []
      end
    else
      @annsets = Annset.all
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @annsets }
    end
  end

  # GET /annsets/:name
  # GET /annsets/:name.json
  def show
    @annset = Annset.find_by_name(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @annset }
    end
  end

  # GET /annsets/new
  # GET /annsets/new.json
  def new
    @annset = Annset.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @annset }
    end
  end

  # GET /annsets/1/edit
  def edit
    @annset = Annset.find_by_name(params[:id])
  end

  # POST /annsets
  # POST /annsets.json
  def create
    @annset = Annset.new(params[:annset])
    respond_to do |format|
      if @annset.save
        format.html { redirect_to annset_path(@annset.name), notice: 'Annset was successfully created.' }
        format.json { render json: @annset, status: :created, location: @annset }
      else
        format.html { render action: "new" }
        format.json { render json: @annset.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /annsets/:name
  # PUT /annsets/:name.json
  def update
    @annset = Annset.find(params[:id])

    respond_to do |format|
      if @annset.update_attributes(params[:annset])
        format.html { redirect_to annset_path(@annset.name), notice: 'Annset was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @annset.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /annsets/:name
  # DELETE /annsets/:name.json
  def destroy
    @annset = Annset.find_by_name(params[:id])
    @annset.destroy

    respond_to do |format|
      format.html { redirect_to annsets_url }
      format.json { head :no_content }
    end
  end
end
