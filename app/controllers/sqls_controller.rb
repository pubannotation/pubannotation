class SqlsController < ApplicationController
  require 'json'
  
  def index
    if params[:sql].present?
      sanitized_sql = ActiveRecord::Base::sanitize(params[:sql]).gsub('\'', '')
      @results = ActiveRecord::Base.connection.execute(sanitized_sql)
    end
  end
end