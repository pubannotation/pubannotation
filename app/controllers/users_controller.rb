class UsersController < ApplicationController
  def autocomplete_username
    @users = User.where(['username like ?', "%#{params[:term]}%"])
      .except_current_user(current_user)
      .except_project_associate_maintainers(params[:project_id])
    render :json => @users.collect{|user| user.username} 
  end
end