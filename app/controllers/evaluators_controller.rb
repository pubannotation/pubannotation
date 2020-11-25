class EvaluatorsController < ApplicationController
	before_filter :set_evaluator, only: [:show, :edit, :update, :destroy]

	respond_to :html

	def index
		@evaluators_grid = initialize_grid(Evaluator.accessibles(current_user),
			order: :name,
			include: :user
		)

		respond_to do |format|
			format.html # index.html.erb
			format.json { render json: Evaluator.all }
		end
	end

	def show
		respond_with(@evaluator)
	end

	def new
		@evaluator = Evaluator.new
		respond_with(@evaluator)
	end

	def edit
	end

	def create
		@evaluator = Evaluator.new(params[:evaluator])
		@evaluator.user = current_user
		@evaluator.save
		respond_with(@evaluator)
	end

	def update
		@evaluator.update_attributes(params[:evaluator])
		respond_with(@evaluator)
	end

	def destroy
		@evaluator.destroy
		respond_with(@evaluator)
	end

	private
		def set_evaluator
			@evaluator = Evaluator.find(params[:id])
		end
end
