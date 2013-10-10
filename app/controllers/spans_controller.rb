class SpansController < ApplicationController
  before_filter :authenticate_user!, :except => [:index, :show, :autocomplete_pmcdoc_sourceid, :autocomplete_pmdoc_sourceid, :search]
  include ApplicationHelper
  
  def sql
    begin
      @search_path = spans_sql_path
      if params[:project_id].present?
        # when search from inner project
        project = Project.find_by_name(params[:project_id])
        if project.present?
          @search_path = project_spans_sql_path
        else
          redirect_to @search_path
        end
      end
      @denotations = Denotation.sql_find(params, current_user.id, project ||= nil).paginate(:page => params[:page], :per_page => 50)
    rescue
      flash[:notice] = t('controllers.shared.sql.invalid')
    end
  end
end