class SqlsController < ApplicationController
  require 'json'
  include ApplicationHelper
  
  def index
    # TODO
    # filter => limit users who can execute this action
    # limit commands => ex: DROP TABLE, DELETE, UPDATE
    if params[:sql].present?
      sanitized_sql =  sanitize_sql(params[:sql])
      @results = ActiveRecord::Base.connection.execute(sanitized_sql).to_a
      @results = @results.paginate(:page => params[:page])
    end
  end
end