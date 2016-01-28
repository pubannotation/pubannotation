class HomeController < ApplicationController
  def index
    unless read_fragment('sourcedbs')
      # @sourcedbs = Doc.select(:sourcedb).sourcedbs.uniq
      @sourcedb_doc_counts = Doc.where("serial = ?", 0).group(:sourcedb).count
      if current_user
      	@sourcedb_doc_counts.delete_if do |sourcedb, doc_count|
      		sourcedb.include?(Doc::UserSourcedbSeparator) && sourcedb.split(Doc::UserSourcedbSeparator)[1] != current_user.username
      	end
      else
      	@sourcedb_doc_counts.delete_if{|sourcedb, doc_count| sourcedb.include?(Doc::UserSourcedbSeparator)}
      end
    end
    @projects_number = Project.accessible(current_user).length
    @projects_top_annotations_count = Project.accessible(current_user).for_home.top_annotations_count
    @projects_top_recent = Project.accessible(current_user).for_home.top_recent
  end
end