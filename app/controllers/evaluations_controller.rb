class EvaluationsController < ApplicationController
	before_filter :authenticate_user!, except: [:index, :show, :result, :falses]
	before_filter :set_evaluation, only: [:edit, :update, :destroy]

	respond_to :html

	def index
		@project = Project.accessible(current_user).find_by_name(params[:project_id])
		raise "There is no such project." unless @project.present?
		@evaluations = Evaluation.all
		@evaluations_grid = initialize_grid(@project.evaluations.accessible(current_user),
			include: [:reference_project, :evaluator]
		)
		respond_with(@evaluations)
	end

	def show
		@project = Project.accessible(current_user).find_by_name(params[:project_id])
		@evaluation = Evaluation.accessible(current_user).find(params[:id])
		@num_docs = (@evaluation.study_project.docs & @evaluation.reference_project.docs).count
		raise "There is no such project." unless @project.present?
		respond_with(@evaluation)
	end

	def new
		@project = Project.accessible(current_user).find_by_name(params[:project_id])
		@evaluation = @project.evaluations.new
		respond_with(@evaluation)
	end

	def edit
		@project = @evaluation.study_project
	end

	def create
		@project = Project.editable(current_user).find_by_name(params[:evaluation][:study_project])
		params[:evaluation][:study_project] = @project.present? ? @project : nil 

		reference_project = Project.accessible(current_user).find_by_name(params[:evaluation][:reference_project])
		params[:evaluation][:reference_project] = reference_project.present? ? reference_project : nil

		evaluator = Evaluator.accessibles(current_user).find_by_name(params[:evaluation][:evaluator])
		params[:evaluation][:evaluator] = evaluator.present? ? evaluator : nil

		params[:evaluation][:denotations_type_match] = nil unless params[:evaluation][:denotations_type_match].present?
		params[:evaluation][:relations_type_match] = nil unless params[:evaluation][:relations_type_match].present?

		params[:evaluation][:user_id] = current_user.id

		@evaluation = Evaluation.new(params[:evaluation])

		respond_to do |format|
			if @evaluation.save
				format.html { redirect_to project_evaluations_path(@project.name), notice: 'Evaluation was successfully created.' }
			else
				format.html { render action: "new" }
			end
		end
	end

	def update
		@project = Project.editable(current_user).find_by_name(params[:evaluation][:study_project])
		params[:evaluation][:study_project] = @project.present? ? @project : nil 

		reference_project = Project.accessible(current_user).find_by_name(params[:evaluation][:reference_project])
		params[:evaluation][:reference_project] = reference_project.present? ? reference_project : nil

		evaluator = Evaluator.accessibles(current_user).find_by_name(params[:evaluation][:evaluator])
		params[:evaluation][:evaluator] = evaluator.present? ? evaluator : nil

		params[:evaluation][:denotations_type_match] = nil unless params[:evaluation][:denotations_type_match].present?
		params[:evaluation][:relations_type_match] = nil unless params[:evaluation][:relations_type_match].present?

		respond_to do |format|
			if @evaluation.update_attributes(params[:evaluation])
				format.html { redirect_to project_evaluation_path(@project.name, @evaluation), notice: 'Evaluation was successfully created.' }
			else
				format.html { render action: "edit" }
			end
		end
	end

	def destroy
		raise "You are not authorized" unless @evaluation.changeable?(current_user)
		@project = @evaluation.study_project
		@evaluation.destroy
		redirect_to project_evaluations_path(@project.name)
	end

	def result
		evaluation = Evaluation.find(params[:evaluation_id])
		render json:evaluation.result
	end

	def falses
		evaluation = Evaluation.find(params[:evaluation_id])
		@study_project = evaluation.study_project
		@reference_project = evaluation.reference_project
		raise "The study project is not accessible." unless @study_project.accessible?(current_user)
		raise "The reference project is not accessible." unless @reference_project.accessible?(current_user)

		result = JSON.parse evaluation.result, symbolize_names: true

		sourcedb = params[:sourcedb]
		sourceid = params[:sourceid]
		divid = params[:divid]
		divid = divid.to_i unless divid.nil?

		@doc = Doc.get_doc(sourcedb:sourcedb, sourceid:sourceid, divid:divid)

		@fps = result[:false_positives].nil? ? [] : result[:false_positives].select{|fp| fp[:sourcedb] == sourcedb && fp[:sourceid] == sourceid && fp[:divid] == divid}
		@fns = result[:false_negatives].nil? ? [] : result[:false_negatives].select{|fn| fn[:sourcedb] == sourcedb && fn[:sourceid] == sourceid && fn[:divid] == divid}
	
		begin
			render layout: 'layouts/popup'
		rescue => e
			render text: "<h1>Something's wrong</h1><p>#{e.message}</p><p>Please re-generate the evaluation result.</p>", layout: 'layouts/popup'
		end
	end

	def generate
		message = begin
			evaluation = Evaluation.find(params[:evaluation_id])
			raise "You are not allowed to (re-)generate the evaluation result." unless evaluation.study_project.editable?(current_user)
			raise "The reference project is not accessible." unless evaluation.reference_project.accessible?(current_user)
			raise "Up to 10 jobs can be registered per project. Please clean your jobs page." unless evaluation.study_project.jobs.count < 10

			if evaluation.evaluator.access_type == 2 # web service
				evaluation.obtain
				"Evaluation is successfuly updated."
			else
				# job = EvaluateAnnotationsJob.new(evaluation)
				# job.perform()

				priority = evaluation.study_project.jobs.unfinished.count
				delayed_job = Delayed::Job.enqueue EvaluateAnnotationsJob.new(evaluation), priority: priority, queue: :general
				Job.create({name:'Evaluate annotations', project_id:evaluation.study_project.id, delayed_job_id:delayed_job.id})
				"The task, 'Evaluate annotations', is created. Please reload the page to see the result."
			end
		rescue => e
			e.message
		end

		redirect_to :back, notice: message
	end

	private
		def set_evaluation
			@evaluation = Evaluation.find(params[:id])
		end
end
