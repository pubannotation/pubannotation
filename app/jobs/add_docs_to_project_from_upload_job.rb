class AddDocsToProjectFromUploadJob < Struct.new(:sourcedb, :filepath, :project)
	include StateManagement

	def perform
		ids = File.readlines(filepath).map(&:chomp)

		@job.update_attribute(:num_items, ids.length)
		@job.update_attribute(:num_dones, 0)

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

		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
		ActionController::Base.new.expire_fragment("count_#{sourcedb}_#{project.name}")

		File.unlink(filepath)
	end
end
