class SessionsController < Devise::SessionsController
  def create
    user = warden.authenticate!(auth_options)
    sign_in(:user, user) if user.persisted?

    render template: 'callbacks/closed_and_reloaded', layout: false
  end
end
