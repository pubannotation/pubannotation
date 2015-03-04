class NoticesController < ApplicationController
  before_filter :authenticate_user!

  def index
    begin
      @project = Project.editable(current_user).find_by_name(params[:project_id])
      raise ArgumentError, "There is no such project in your management." unless @project.present?

      @notices = @project.notices
    rescue ArgumentError => e
      format.html {redirect_to home_path, :notice => e.message}
    end
  end

  def tasks
    begin
      @project = Project.editable(current_user).find_by_name(params[:project_id])
      raise ArgumentError, "There is no such project in your management." unless @project.present?

      notices = @project.notices.order(:created_at)

      @tasks = notices.inject({}) do |tasks, notice|
        if notice.successful.nil?
          tasks[notice.method] = {}
          tasks[notice.method][:method] = notice.method
          tasks[notice.method][:registered_at] = notice.created_at
        else
          tasks[notice.method][:finished_at] = notice.created_at
          tasks[notice.method][:result] = notice.successful
        end
        tasks
      end.values

      @complete = true
      @tasks.each{|t| if t[:finished_at].nil? then @complete = false; break end}

    rescue ArgumentError => e
      format.html {redirect_to home_path, :notice => e.message}
    end
  end

  def destroy
    notice = Notice.find_by_id(params[:id])
    if notice.present? && notice.project.notices_destroyable_for?(current_user) && notice.delete
       text = "$('#notice_#{params[:id]}').hide();"
    else
      text = "$('#notice_#{params[:id]}').text('#{t('errors.messages.failed_to_destroy')}');"
    end
    render text: text
  end

  def delete_project_notices
    project = Project.find(params[:id])
    project.notices.delete_all
    text = "$('#project_notices').text('');"
    render text: text
  end
end
