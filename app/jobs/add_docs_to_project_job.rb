class AddDocsToProjectJob < Struct.new(:docspecs, :project)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, docspecs.length)
		@job.update_attribute(:num_dones, 0)
    docspecs.each_with_index do |docspec, i|
    	begin
	      project.add_doc(docspec[:sourcedb], docspec[:sourceid], true)
	    rescue => e
				@job.messages << Message.create({item: "#{docspec[:sourcedb]}:#{docspec[:sourceid]}", body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
    end
	end
end
