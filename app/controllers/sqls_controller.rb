class SqlsController < ApplicationController
  require 'json'
  
  def index
    # TODO
    # filter => limit users who can execute this action
    # limit commands => ex: DROP TABLE, DELETE, UPDATE
    if params[:sql].present?
      sanitized_sql = ActiveRecord::Base::sanitize(params[:sql]).gsub('\'', '')
      @results = ActiveRecord::Base.connection.execute(sanitized_sql)
      @results = @results.paginate(:page => params[:page])
    end
  end
end