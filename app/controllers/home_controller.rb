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
    @projects_top = Project.accessible(current_user).top(current_user)
  end

  def index_projects_annotations_rdf
	  begin
	    raise RuntimeError, "Not authorized" unless current_user.root? == true
	    system = Project.find_by_name('system-maintenance')
	    system.notices.create({method: "index projects annotations rdf"})
	    system.delay.index_projects_annotations_rdf
	  rescue => e
	    flash[:notice] = e.message
	  end
	  redirect_to project_path('system-maintenance')
	end
end
