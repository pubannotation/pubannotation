class SpansController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :search]
  include ApplicationHelper
  
  def sql
    if params[:sql].present?
      sanitized_sql =  sanitize_sql(params[:sql])
      @results = Denotation.connection.execute(sanitized_sql)
      @ids = @results.collect{| result | result['id']}
      @denotations = Denotation.sql(@ids, current_user.id).paginate(:page => params[:page], :per_page => 50) 
    end
  end
end