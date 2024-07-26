class AnnotationReceptionController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update; end

end
