class SpansController < ApplicationController
  def sql
    if params[:sql].present?
      sanitized_sql = ActiveRecord::Base::sanitize(params[:sql]).gsub('\'\'', '"').gsub('\'', '')
      @results = Denotation.connection.execute(sanitized_sql)
      @ids = @results.collect{| result | result['id']}
      @denotations = Denotation.where('id IN(?)', @ids).includes(:doc).order('id ASC').paginate(:page => params[:page], :per_page => 50)
    end
  end
end