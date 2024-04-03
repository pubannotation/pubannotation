class AnnotatorsController < ApplicationController
	include IniFileConvertible
	before_action :changeable?, :only => [:edit, :update, :destroy]
	before_action :authenticate_user!, :only => [:new, :edit, :destroy]

	# GET /annotators
	# GET /annotators.json
	def index
		@annotators_grid = initialize_grid(Annotator.accessibles(current_user),
			order: :updated_at,
			order_direction: :desc,
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
		message = ""
		begin
			@annotator = Annotator.accessibles(current_user).find(params[:id])
		rescue
			raise "Could not find the annotator, #{params[:id]}."
		end

		@result = if params[:text]
			begin
				@annotator.obtain_annotations([{text:params[:text]}]).first
			rescue => e
				message = "A problem is reported from the server: #{e.message}."
				nil
			end
		end

		respond_to do |format|
			format.html {flash[:notice] = message}
			format.json { render json: @annotator }
		end
	rescue => e
		respond_to do |format|
			format.html {flash[:notice] = message}
			format.json {head :unprocessable_entity}
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
	end

	# POST /annotators
	# POST /annotators.json
	def create
		params = annotator_params
		params[:payload] = convert_str_to_hash(params[:payload])
		params[:user] = current_user
		@annotator = Annotator.new(params)

		respond_to do |format|
			if @annotator.save
				format.html { redirect_to @annotator, notice: 'Annotator was successfully created.' }
				format.json { render json: @annotator, status: :created, location: @annotator }
			else
				format.html {
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
		params = annotator_params
		if params['method'] == '0'
			params['payload'] = nil
		end
		params['payload'] = convert_str_to_hash(params['payload'])

		respond_to do |format|
			if @annotator.update(params)
				format.html { redirect_to @annotator, notice: 'Annotator was successfully updated.' }
				format.json { head :no_content }
			else
				format.html {
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

	private

	def annotator_params
		params.require(:annotator).permit(:name, :description, :home, :url, :method, :payload, :max_text_size,
																			:async_protocol, :is_public, :sample, :receiver_attribute, :new_label)
	end

	def changeable?
		@annotator = Annotator.find(params[:id])
		render_status_error(:forbidden) unless @annotator.changeable?(current_user)
	end
end
