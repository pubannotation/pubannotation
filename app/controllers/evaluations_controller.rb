class EvaluationsController < ApplicationController
	before_action :authenticate_user!, except: [:index, :show, :result, :index_falses, :falses]
	before_action :set_evaluation, only: [:edit, :update, :destroy]

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
		permitted_evaluation_params = evaluation_params
		@project = Project.editable(current_user).find_by_name(permitted_evaluation_params[:study_project])
		permitted_evaluation_params[:study_project] = @project.present? ? @project : nil

		reference_project = Project.accessible(current_user).find_by_name(permitted_evaluation_params[:reference_project])
		permitted_evaluation_params[:reference_project] = reference_project.present? ? reference_project : nil

		evaluator = Evaluator.accessibles(current_user).find_by_name(permitted_evaluation_params[:evaluator])
		permitted_evaluation_params[:evaluator] = evaluator.present? ? evaluator : nil

		permitted_evaluation_params[:denotations_type_match] = nil unless permitted_evaluation_params[:denotations_type_match].present?
		permitted_evaluation_params[:relations_type_match] = nil unless permitted_evaluation_params[:relations_type_match].present?

		permitted_evaluation_params[:user_id] = current_user.id

		@evaluation = Evaluation.new(permitted_evaluation_params)

		respond_to do |format|
			if @evaluation.save
				format.html { redirect_to project_evaluations_path(@project.name), notice: 'Evaluation was successfully created.' }
			else
				format.html { render action: "new" }
			end
		end
	end

	def update
		permitted_evaluation_params = evaluation_params
		@project = Project.editable(current_user).find_by_name(permitted_evaluation_params[:study_project])
		permitted_evaluation_params[:study_project] = @project.present? ? @project : nil

		reference_project = Project.accessible(current_user).find_by_name(permitted_evaluation_params[:reference_project])
		permitted_evaluation_params[:reference_project] = reference_project.present? ? reference_project : nil

		evaluator = Evaluator.accessibles(current_user).find_by_name(permitted_evaluation_params[:evaluator])
		permitted_evaluation_params[:evaluator] = evaluator.present? ? evaluator : nil

		permitted_evaluation_params[:denotations_type_match] = nil unless permitted_evaluation_params[:denotations_type_match].present?
		permitted_evaluation_params[:relations_type_match] = nil unless permitted_evaluation_params[:relations_type_match].present?

		respond_to do |format|
			if @evaluation.update(permitted_evaluation_params)
				format.html { redirect_to project_evaluation_path(@project.name, @evaluation), notice: 'Evaluation was successfully created.' }
			else
				format.html { render action: "edit" }
			end
		end
	end

	def destroy
		render_status_error(:forbidden) unless @evaluation.changeable?(current_user)

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
		type     = params[:type]
		element  = params[:element]
		element  = nil if element && element == 'All'

		@doc = Doc.get_doc(sourcedb:sourcedb, sourceid:sourceid)

		element_key = type == 'relation' ? :pred : :obj

		@fps = result[:false_positives] || {}
		@fps = @fps.select{|c| c[:sourcedb] == sourcedb && c[:sourceid] == sourceid}
		@fps = @fps.select{|c| c[:type] == type} unless type.nil?
		@fps = @fps.select{|c| c[:study][element_key] == element} unless element.nil?

		@fns = result[:false_negatives] || {}
		@fns = @fns.select{|c| c[:sourcedb] == sourcedb && c[:sourceid] == sourceid}
		@fns = @fns.select{|c| c[:type] == type} unless type.nil?
		@fns = @fns.select{|c| c[:reference][element_key] == element} unless element.nil?
	
		begin
			render layout: 'layouts/popup'
		rescue => e
			render plain: "<h1>Something's wrong</h1><p>#{e.message}</p><p>Please re-generate the evaluation result.</p>", layout: 'layouts/popup'
		end
	end

	def index_falses
		@evaluation = Evaluation.accessible(current_user).find(params[:evaluation_id])
	end

	def index_tps
		evaluation = Evaluation.accessible(current_user).find(params[:evaluation_id])

		@type = params[:type]
		@element = params[:element]
		@element = nil if @element && @element == 'All'
		@sort_key = params[:sort_key]&.to_sym

		respond_to do |format|
			format.html {
				@tps = evaluation.true_positives(@type, @element, @sort_key)
				@sproject = evaluation.study_project
				@rproject = evaluation.reference_project
			}
			format.tsv {
				send_data evaluation.true_positives_csv(@type, @element, @sort_key), filename: "true_positives_#{@element || 'all'}_type_#{@type}s.csv"
			}
		end
	end

	def index_fps
		evaluation = Evaluation.accessible(current_user).find(params[:evaluation_id])

		@type = params[:type]
		@element = params[:element]
		@element = nil if @element && @element == 'All'
		@sort_key = params[:sort_key]&.to_sym

		respond_to do |format|
			format.html {
				@fps = evaluation.false_positives(@type, @element, @sort_key)
				@sproject = evaluation.study_project
				@rproject = evaluation.reference_project
			}
			format.tsv {
				send_data evaluation.false_positives_csv(@type, @element, @sort_key), filename: "false_positives_#{@element || 'all'}_type_#{@type}s.csv"
			}
		end
	end

	def index_fns
		evaluation = Evaluation.accessible(current_user).find(params[:evaluation_id])

		@type = params[:type]
		@element = params[:element]
		@element = nil if @element && @element == 'All'
		@sort_key = params[:sort_key]&.to_sym

		respond_to do |format|
			format.html {
				@fns = evaluation.false_negatives(@type, @element, @sort_key)
				@sproject = evaluation.study_project
				@rproject = evaluation.reference_project
			}
			format.tsv {
				send_data evaluation.false_negatives_csv(@type, @element, @sort_key), filename: "false_negatives_#{@element || 'all'}_type_#{@type}s.csv"
			}
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
				# EvaluateAnnotationsJob.perform_now(evaluation)

				active_job = EvaluateAnnotationsJob.perform_later(evaluation)
				"The task, '#{active_job.job_name}', is created. Please reload the page to see the result."
			end
		rescue => e
			e.message
		end

		redirect_back fallback_location: root_path, notice: message
	end

	private
		def set_evaluation
			@evaluation = Evaluation.find(params[:id])
		end

		def evaluation_params
			params.require(:evaluation).permit(:result, :is_public, :study_project, :reference_project, :evaluator, :note, :user_id,
																				 :soft_match_characters, :soft_match_words, :denotations_type_match, :relations_type_match)
		end
end
