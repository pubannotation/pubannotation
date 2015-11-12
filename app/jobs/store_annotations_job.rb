class StoreAnnotationsJob < Struct.new(:annotations, :project, :divs, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, 1)
		@job.update_attribute(:num_dones, 0)
    project.store_annotations(annotations, divs, options)
		@job.update_attribute(:num_dones, 1)
	end
end
