class AnnsetsController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show]

  # GET /annsets
  # GET /annsets.json
  def index
    sourcedb, sourceid, serial = get_docspec(params)
    if sourcedb
      @doc = Doc.find_by_sourcedb_and_sourceid_and_serial(sourcedb, sourceid, serial)
      if @doc
        @annsets = get_annsets(@doc)
      else
        @annsets = nil
        notice = "The document, #{sourcedb}:#{sourceid}, does not exist in PubAnnotation."
      end
    else
      @annsets = get_annsets()
    end

    respond_to do |format|
      format.html {
        if @doc and @annsets == nil
          redirect_to home_path, :notice => notice
        end
      }
      format.json { render json: @annsets }
    end
  end

  # GET /annsets/:name
  # GET /annsets/:name.json
  def show
    @annset, notice = get_annset(params[:id])
    if @annset
      sourcedb, sourceid, serial = get_docspec(params)
      if sourceid
        @doc, notice = get_doc(sourcedb, sourceid, serial, @annset)
      else
        docs = @annset.docs
        @pmdocs_num = docs.select{|d| d.sourcedb == 'PubMed'}.length
        @pmcdocs_num = docs.select{|d| d.sourcedb == 'PMC' and d.serial == 0}.length
      end
    end

    respond_to do |format|
      if @annset
        format.html { flash[:notice] = notice }
        format.json { render json: @annset }
      else
        format.html {
          redirect_to home_path, :notice => notice
        }
        format.json { head :unprocessable_entity }
      end
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
    @sourcedb, @sourceid, @serial = get_docspec(params)
    @annset = Annset.find_by_name(params[:id])
  end

  # POST /annsets
  # POST /annsets.json
  def create
    @annset = Annset.new(params[:annset])
    @annset.user = current_user
    
    respond_to do |format|
      if @annset.save
        format.html { redirect_to annset_path(@annset.name), :notice => 'Annotation set was successfully created.' }
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
        format.html { redirect_to annset_path(@annset.name), :notice => 'Annotation set was successfully updated.' }
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
      format.html { redirect_to annsets_path, notice: "The annotation set, #{params[:id]}, was deleted." }
      format.json { head :no_content }
    end
  end
end
