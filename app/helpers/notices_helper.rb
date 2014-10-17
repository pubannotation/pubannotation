module NoticesHelper
  def notices_list_helper
    render partial: 'notices/notice', collection: @notices if @project.notices_destroyable_for?(current_user)
  end
end
