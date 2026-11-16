class ConfirmationsController < Devise::ConfirmationsController
  def show
    resource = resource_class.find_by_confirmation_token(params[:confirmation_token])
    return super if resource.nil? || resource.confirmed?

    resource.confirm
    set_flash_message :notice, :confirmed
    sign_in_and_redirect(resource)
  end
end
