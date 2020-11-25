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
		@sequencer.parameters = @sequencer.parameters.map{|p| p.join(' = ')}.join("\n")
		respond_with(@sequencer)
	end

	def new
		@sequencer = Sequencer.new
		respond_with(@sequencer)
	end

	def edit
		@sequencer = Sequencer.find(params[:id])
		@sequencer.parameters = @sequencer.parameters.map{|p| p.join(' = ')}.join("\n")
	end

	def create
		@sequencer = Sequencer.new(params[:sequencer])
		@sequencer.user = current_user
		@sequencer.parameters = @sequencer.parameters.delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if @sequencer.parameters.present?
		@sequencer.save
		respond_with(@sequencer)
	end

	def update
		@sequencer = Sequencer.find(params[:id])
		update = params[:sequencer]
		update['parameters'] = update['parameters'].delete(' ').split(/[\n\r\t]+/).map{|p| p.split(/[:=]/)}.to_h if update['parameters'].present?

		@sequencer.update_attributes(update)
		@sequencer.name = update['name']
		respond_with(@sequencer)
	end

	def destroy
		@sequencer = Sequencer.find(params[:id])
		@sequencer.destroy
		respond_with(@sequencer)
	end

	def changeable?
		@sequencer = Sequencer.find(params[:id])
		render_status_error(:forbidden) unless @sequencer.changeable?(current_user)
	end
end
