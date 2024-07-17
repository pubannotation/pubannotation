class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters
  before_action :validate_recaptcha, only: [:create]

  protected
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up) do |u|
        u.permit(:username, :email, :password, :password_confirmation)
      end
      devise_parameter_sanitizer.permit(:account_update) do |u|
        u.permit(:username, :email, :password, :password_confirmation, :current_password)
      end
    end

  private

  def validate_recaptcha
    self.resource = resource_class.new(sign_up_params)
    resource.validate # Without this, all validations will not be displayed.

    unless verify_recaptcha(model: resource)
      respond_with_navigational(resource) { render :new }
    end
  end
end
