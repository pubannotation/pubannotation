class DocsController < ApplicationController
  # GET /docs
  # GET /docs.json
  def index
    @docs = Doc.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @docs }
    end
  end

  # GET /docs/1
  # GET /docs/1.json
  def show
    @doc = Doc.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @doc }
    end
  end

  # GET /docs/new
  # GET /docs/new.json
  def new
    @doc = Doc.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @doc }
    end
  end

  # GET /docs/1/edit
  def edit
    @doc = Doc.find(params[:id])
  end

  # POST /docs
  # POST /docs.json
  def create
    @doc = Doc.new(params[:doc])

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
