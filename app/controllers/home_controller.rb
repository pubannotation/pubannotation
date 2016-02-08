class HomeController < ApplicationController
  def index
    unless read_fragment('docs_count_per_sourcedb')
      @docs_count_per_sourcedb = Doc.docs_count_per_sourcedb(current_user)
    end
    @projects_number = Project.accessible(current_user).length
    @projects_top_annotations_count = Project.accessible(current_user).for_home.top_annotations_count
    @projects_top_recent = Project.accessible(current_user).for_home.top_recent
  end
end
