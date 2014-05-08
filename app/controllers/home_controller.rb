class HomeController < ApplicationController
  def index
    @source_dbs = Doc.select(:sourcedb).source_dbs.uniq

    if params[:sort_key]
      @sort_order = flash[:sort_order]
      @sort_order.delete(@sort_order.assoc(params[:sort_key]))
      @sort_order.unshift([params[:sort_key], params[:sort_direction]])
    else
      # initialize the sort order
      # @sort_order = [['name', 'ASC'], ['author', 'ASC'], ['user_id', 'ASC']]
      @sort_order = [['name', 'ASC'], ['author', 'ASC']]
    end

    @projects = Project.unscoped.accessible(current_user).order(@sort_order.collect{|s| s.join(' ')}.join(', '))
    flash[:sort_order] = @sort_order
  end
end
