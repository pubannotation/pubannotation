class AnnsetsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]

  # GET /annsets
  # GET /annsets.json
  def index
    @sourcedb, @sourceid, @serial = get_docspec(params)

    if @sourceid
      if @serial
        @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(@sourcedb, @sourceid, @serial)
      else
        @doc = Doc.find_all_by_sourcedb_and_sourceid(@sourcedb, @sourceid)
      end

      if @doc
        @annsets = @doc.annsets.uniq
      else
        @annsets = []
      end
    else
      @annsets = Annset.order('name ASC').all
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @annsets }
    end
  end

  # GET /annsets/:name
  # GET /annsets/:name.json
  def show
    @sourcedb, @sourceid, @serial = get_docspec(params)
    @annset = Annset.find_by_name(params[:id])

    unless @sourceid
      docs = @annset.docs.uniq.keep_if{|d| d.serial == 0}
      @docs_num = docs.length
      @pmdocs_num = docs.select{|d| d.sourcedb == 'PubMed'}.length
      @pmcdocs_num = docs.select{|d| d.sourcedb == 'PMC'}.length
    end

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @annset }
    end
  end

  # GET /annsets/new
  # GET /annsets/new.json
  def new
    @annset = Annset.new
    @annset.uploader = current_user.email

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
