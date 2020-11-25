class CallbacksController < Devise::OmniauthCallbacksController
	def google_oauth2
		user = User.from_omniauth(request.env["omniauth.auth"])
		sign_in(:user, user) if user.persisted?

		render :closed_and_reloaded, layout: false
	end
end
