class AddDocsToProjectJob < Struct.new(:docspecs, :project)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, docspecs.length)
		@job.update_attribute(:num_dones, 0)

		sourcedbs = []
    docspecs.each_with_index do |docspec, i|
    	begin
				added = project.add_doc_unless_exist(docspec[:sourcedb], docspec[:sourceid])
				sourcedbs << docspec[:sourcedb] unless added.nil?
	    rescue => e
				@job.messages << Message.create({sourcedb: docspec[:sourcedb], sourceid: docspec[:sourceid], body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
    end
    unless sourcedbs.empty?
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			sourcedbs.uniq.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
		end
	end
end
