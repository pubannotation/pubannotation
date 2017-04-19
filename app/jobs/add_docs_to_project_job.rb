class AddDocsToProjectJob < Struct.new(:docspecs, :project)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, docspecs.length)
		@job.update_attribute(:num_dones, 0)

		docspecs_group_by_sourcedb = docspecs.group_by{|docspec| docspec[:sourcedb]}
		docspecs_group_by_sourcedb.each do |sourcedb, docspecs|
			ids = docspecs.map{|docspec| docspec[:sourceid]}
			added, messages =
				begin
					project.add_docs(sourcedb, ids)
		    rescue => e
					@job.messages << Message.create({sourcedb: sourcedb, sourceid: "#{ids.first} - #{ids.last}", body: e.message})
					[[], []]
				end
			messages.each{|message| @job.messages << Message.create({body: message})}
			num_added_docs = added.map{|d| d[:sourceid]}.uniq.length
      @job.update_attribute(:num_dones, @job.num_dones + num_added_docs)
		end
		sourcedbs = docspecs_group_by_sourcedb.keys
    unless sourcedbs.empty?
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			sourcedbs.uniq.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
		end
	end
end
