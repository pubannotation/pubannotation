class SequencersController < ApplicationController
	before_filter :changeable?, :only => [:edit, :update, :destroy]
	before_filter :authenticate_user!, :only => [:new, :edit, :destroy]
	respond_to :html

	def index
		@sequencers = Sequencer.all
		@sequencers_grid = initialize_grid(Sequencer.accessibles(current_user),
			order: :name,
			include: :user
		)
		respond_with(@sequencers)
	end

	def show
		@sequencer = Sequencer.find(params[:id])
		respond_with(@sequencer)
	end

	def new
		if root_user? || manager?
			@sequencer = Sequencer.new
			respond_with(@sequencer)
		else
			redirect_to root_path, notice: "Unauthorized"
		end
	end

	def edit
		if root_user? || manager?
			@sequencer = Sequencer.find(params[:id])
		else
			redirect_to root_path, notice: "Unauthorized"
		end
	end

	def create
		if root_user? || manager?
			params = sequencer_params
			params[:parameters] = parameters_to_hash(params[:parameters])
			params[:user] = current_user
			@sequencer = Sequencer.create(params)
			respond_with(@sequencer)
		else
			redirect_to root_path, notice: "Unauthorized"
		end
	end

	def update
		if root_user? || manager?
			@sequencer = Sequencer.find(params[:id])
			params = sequencer_params
			params[:parameters] = parameters_to_hash(params[:parameters])

			@sequencer.update_attributes(params)
			@sequencer.name = params[:name]
			respond_with(@sequencer)
		else
			redirect_to root_path, notice: "Unauthorized"
		end
	end

	def destroy
		if root_user? || manager?
			@sequencer = Sequencer.find(params[:id])
			@sequencer.destroy
			respond_with(@sequencer)
		else
			redirect_to root_path, notice: "Unauthorized"
		end
	end

	def changeable?
		@sequencer = Sequencer.find(params[:id])
		render_status_error(:forbidden) unless @sequencer.changeable?(current_user)
	end

	private
		def sequencer_params
			params.require(:sequencer).permit(:description, :home, :name, :parameters, :url, :is_public)
		end

		def parameters_to_hash(parameters)
			parameters.delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if parameters.present?
		end
end
