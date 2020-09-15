class DeleteAllAnnotationsFromProjectJob < Struct.new(:project)
	include StateManagement

	def perform
		docs = project.docs
		@job.update_attribute(:num_items, 1)
		@job.update_attribute(:num_dones, 0)
		begin
			project.delete_annotations
		rescue => e
			@job.messages << Message.create({body: e.message})
		end
		@job.update_attribute(:num_dones, 1)
		project.update_attribute(:annotations_count, 0)
	end
end
