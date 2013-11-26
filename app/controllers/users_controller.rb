class UsersController < ApplicationController
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