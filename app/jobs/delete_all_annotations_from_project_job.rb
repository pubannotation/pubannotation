class DeleteAllAnnotationsFromProjectJob < Struct.new(:project)
	include StateManagement

	def perform
    docs = project.docs
		@job.update_attribute(:num_items, docs.length)
    @job.update_attribute(:num_dones, 0)
    docs.each_with_index do |doc, i|
      begin
        project.delete_annotations(doc)
      rescue => e
				@job.messages << Message.create({item: "#{doc.sourcedb}:#{doc.sourceid}", body: e.message})
      end
			@job.update_attribute(:num_dones, i + 1)
    end
    project.update_attribute(:annotations_count, 0)
	end
end
