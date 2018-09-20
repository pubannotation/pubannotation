class CallbacksController < Devise::OmniauthCallbacksController
  @@from

  def google_oauth2
    @user = User.from_omniauth(request.env["omniauth.auth"])
    #パラメータを保存
    @@from = request.env['omniauth.params']['from']

    sign_in_and_redirect @user
  end

  def github
    logger.debug request.env['omniauth.auth'].inspect
    @user = User.from_omniauth(request.env["omniauth.auth"])
    #パラメータを保存
    @@from = request.env['omniauth.params']['from']

    sign_in_and_redirect @user
  end

  def after_sign_in_path_for(resource)
    # リダイレクト先変更
    if @@from == 'textae'
      '/api/loggedin'
    else
      root_path
    end
  end

end