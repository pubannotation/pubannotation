class NoticesController < ApplicationController
  before_filter :authenticate_user!

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
