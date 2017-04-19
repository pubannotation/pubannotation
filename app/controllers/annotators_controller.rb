class AnnotatorsController < ApplicationController
  before_filter :changeable?, :only => [:edit, :update, :destroy]
  before_filter :authenticate_user!, :only => [:new, :edit, :destroy]

  # GET /annotators
  # GET /annotators.json
  def index
    @annotators_grid = initialize_grid(Annotator.accessibles(current_user),
      order: :name,
      include: :user
    )

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @annotators }
    end
  end

  # GET /annotators/1
  # GET /annotators/1.json
  def show
    @annotator = Annotator.find(params[:id])
    @annotator.payload = @annotator.payload.map{|p| p.join(' = ')}.join("\n")

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @annotator }
    end
  end

  # GET /annotators/new
  # GET /annotators/new.json
  def new
    @annotator = Annotator.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @annotator }
    end
  end

  # GET /annotators/1/edit
  def edit
    @annotator = Annotator.find(params[:id])
    @annotator.payload = @annotator.payload.map{|p| p.join(' = ')}.join("\n")
  end

  # POST /annotators
  # POST /annotators.json
  def create
    @annotator = Annotator.new(params[:annotator])
    @annotator.user = current_user
    @annotator.payload = @annotator.payload.delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if @annotator.payload.present?

    respond_to do |format|
      if @annotator.save
        format.html { redirect_to @annotator, notice: 'Annotator was successfully created.' }
        format.json { render json: @annotator, status: :created, location: @annotator }
      else
        format.html {
          @annotator.payload = @annotator.payload.map{|p| p.join(' = ')}.join("\n")
          render action: "new"
        }
        format.json { render json: @annotator.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /annotators/1
  # PUT /annotators/1.json
  def update
    @annotator = Annotator.find(params[:id])
    update = params[:annotator]
    if update['method'] == '0'
      update['payload'] = nil
      update['batch_num'] = 0
    end
    update['payload'] = update['payload'].delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if update['payload'].present?

    respond_to do |format|
      if @annotator.update_attributes(params[:annotator])
        format.html { redirect_to @annotator, notice: 'Annotator was successfully updated.' }
        format.json { head :no_content }
      else
        format.html {
          @annotator.payload = @annotator.payload.map{|p| p.join(' = ')}.join("\n")
          render action: "edit"
        }
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

  def changeable?
    @annotator = Annotator.find(params[:id])
    render_status_error(:forbidden) unless @annotator.changeable?(current_user)
  end
end
