class ApiController < ApplicationController
  def login
    if user_signed_in?
      redirect_to controller: 'api', action: 'loggedin'
    else
      # ログイン後にAPI用のURLに飛ばす
      session[:previous_url] = '/api/loggedin'
      render :login, layout: 'api'
    end
  end
  

  def loggedin
    render :loggedin, layout: 'api'
  end 
end
