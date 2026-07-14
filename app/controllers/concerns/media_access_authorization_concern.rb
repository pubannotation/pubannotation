# frozen_string_literal: true

module MediaAccessAuthorizationConcern
  extend ActiveSupport::Concern

  private

  def authorize_media_access!
    unless current_user&.can_access_media?
      render_status_error(:forbidden)
    end
  end
end
