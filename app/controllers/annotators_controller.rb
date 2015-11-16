class AnnotatorsController < ApplicationController
  before_filter :authenticate_user!, :only => [:new, :edit, :destroy]

  # GET /annotators
  # GET /annotators.json
  def index
    @annotators = Annotator.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @annotators }
    end
  end

  # GET /annotators/1
  # GET /annotators/1.json
  def show
    @annotator = Annotator.find(params[:id])
    @annotator.params = @annotator.params.map{|p| p.join("=")}.join("\n")
    @annotator.params2 = @annotator.params2.map{|p| p.join("=")}.join("\n")

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @annotator }
    end
  end

  # GET /annotators/new
  # GET /annotators/new.json
  def new
    @annotator = Annotator.new
    @annotator.params = @annotator.params.map{|p| p.join("=")}.join("\n")
    @annotator.params2 = @annotator.params2.map{|p| p.join("=")}.join("\n")

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @annotator }
    end
  end

  # GET /annotators/1/edit
  def edit
    @annotator = Annotator.find(params[:id])
    @annotator.params = @annotator.params.map{|p| p.join("=")}.join("\n")
    @annotator.params2 = @annotator.params2.map{|p| p.join("=")}.join("\n")
  end

  # POST /annotators
  # POST /annotators.json
  def create
    @annotator = Annotator.new(params[:annotator])
    @annotator.user = current_user
    @annotator.params = @annotator.params.split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h
    @annotator.params2 = @annotator.params2.split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h

    respond_to do |format|
      if @annotator.save
        format.html { redirect_to @annotator, notice: 'Annotator was successfully created.' }
        format.json { render json: @annotator, status: :created, location: @annotator }
      else
        format.html { render action: "new" }
        format.json { render json: @annotator.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /annotators/1
  # PUT /annotators/1.json
  def update
    @annotator = Annotator.find(params[:id])
    update = params[:annotator]
    update["params"] = update["params"].split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h
    update["params2"] = update["params2"].split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h

    respond_to do |format|
      if @annotator.update_attributes(params[:annotator])
        format.html { redirect_to @annotator, notice: 'Annotator was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @annotator.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /annotators/1
  # DELETE /annotators/1.json
  def destroy
    @annotator = Annotator.find(params[:id])
    @annotator.destroy

    respond_to do |format|
      format.html { redirect_to annotators_url }
      format.json { head :no_content }
    end
  end
end
