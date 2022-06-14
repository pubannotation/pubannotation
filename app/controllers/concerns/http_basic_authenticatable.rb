module HTTPBasicAuthenticatable
  include ActiveSupport::Concern

  def http_basic_authenticate 
		authenticate_or_request_with_http_basic do |username, password|
			user = User.find_by_email(username)
			if user.present? && user.valid_password?(password)
				sign_in :user, user 
			else
				respond_to do |format|
					format.json{
						res = {
							status: :unauthorized,
							message: 'Authentication Failed'
						}
						render json: res.to_json
					}
				end
			end
		end
	end
end