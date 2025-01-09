class TextaeController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[create show]

  def create
  end

  def show
  end
end
