class SpansController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :search]
  include ApplicationHelper
  
  def sql
    if params[:sql].present?
      accessible_project_ids = Project.accessible(current_user).collect{|project| project.id}
      sanitized_sql =  sanitize_sql(params[:sql])
      @results = Denotation.connection.execute(sanitized_sql)
      @ids = @results.collect{| result | result['id']}
      @denotations = Denotation.
        where('project_id IN(?)', accessible_project_ids).
        where('id IN(?)', @ids).
        includes(:doc).order('id ASC').paginate(:page => params[:page], :per_page => 50)
    end
  end
end