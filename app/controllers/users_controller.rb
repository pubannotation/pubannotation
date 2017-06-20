class UsersController < ApplicationController
  before_filter :is_root_user?, only: :index
  
  def index
    @users = User.all.page(params[:page]) 
  end

  def show
    @user = User.find_by_username(params[:name])
    @projects = Project.mine(@user)

    @projects_grid = initialize_grid(Project.accessible(current_user), conditions:{user_id: @user.id}, per_page: 10)
    @annotators_grid = initialize_grid(Annotator.accessibles(current_user), conditions:{user_id: @user.id}, per_page: 10)
    @editors_grid = initialize_grid(Editor.accessibles(current_user), conditions:{user_id: @user.id}, per_page: 10)
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
