class RelationsController < ApplicationController
  include ApplicationHelper

  def sql
    @search_path = relations_sql_path 
    @columns = [:hid, :subj_id, :subj_type, :obj_id, :obj_type, :project_id]
    begin
      if params[:project_id].present?
        # when search from inner project
        project = Project.find_by_name(params[:project_id])
        if project.present?
          @search_path = project_relations_sql_path
        else
          @redirected = true
          redirect_to @search_path
        end
      end     
      @relations = Relation.sql_find(params, current_user, project ||= nil)
      if @relations.present?
        @relations = @relations.page(params[:page]).per(50)
      end
    rescue => error
      flash[:notice] = "#{t('controllers.shared.sql.invalid')} #{error}"
    end
  end
end