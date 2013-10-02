class SpansController < ApplicationController
  def sql
    if params[:sql].present?
      sanitized_sql = ActiveRecord::Base::sanitize(params[:sql]).gsub('\'', '')
      @results = Denotation.connection.execute(sanitized_sql)
      @results = @results.paginate(:page => params[:page], :per_page => 50)
    end
  end
end