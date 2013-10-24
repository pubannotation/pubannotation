class SpansController < ApplicationController
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
      @denotations = Denotation.sql_find(params, current_user, project ||= nil)
      if @denotations.present?
        @denotations = @denotations.paginate(:page => params[:page], :per_page => 50)
      end
    rescue => error
      flash[:notice] = "#{t('controllers.shared.sql.invalid')} #{error}"
    end
  end
end