class Users::PasswordsController < Devise::PasswordsController
  include Recaptchable

  before_action :validate_recaptcha, only: [:create], if: :recaptcha_usable?

  private

  def validate_recaptcha
    self.resource = resource_class.new

    unless verify_recaptcha(model: resource)
      respond_with_navigational(resource) { render :new }
    end
  end
end
