class UsersController < ApplicationController
	before_action :is_root_user?, only: :index
	
	def index
		@users_grid = initialize_grid(User, per_page: 10)
	end

	def show
		@user = User.find_by_username(params[:name])

		if @user == current_user && current_user.root?
			@num_waiting = Job.waiting.count
			@num_running = Job.running.count
			@num_finished = Job.finished.count

			@jobs_grid = initialize_grid(Job.unfinished)
		else
			@collections_grid = initialize_grid(Collection.accessible(current_user), name: "cg", conditions:{user_id: @user.id}, per_page: 10)
			@projects_grid = initialize_grid(Project.accessible(current_user), name: "pg", conditions:{user_id: @user.id}, per_page: 10)
			@annotators_grid = initialize_grid(Annotator.accessibles(current_user), name: "ag", conditions:{user_id: @user.id}, per_page: 10)
			@editors_grid = initialize_grid(Editor.accessibles(current_user), name: "eg", conditions:{user_id: @user.id}, per_page: 10)
		end
	end

	def autocomplete_username
		if params[:project_id].blank?
			# when search with new project
			@users = User.where(['username like ?', "%#{params[:term]}%"])
				.except_current_user(current_user)
			render :json => @users.collect{|user| user.username}
		else
			# when search with saved project
			@users = User.where(['username like ?', "%#{params[:term]}%"])
				.except_current_user(current_user)
				.except_project_associate_maintainers(params[:project_id])
			render :json => @users.collect{|user| user.username}
		end 
	end
end
