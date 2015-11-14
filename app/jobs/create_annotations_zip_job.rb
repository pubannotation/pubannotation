class CreateAnnotationsZipJob < Struct.new(:project)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, 1)
		@job.update_attribute(:num_dones, 0)
    project.create_annotations_zip
		@job.update_attribute(:num_dones, 1)
	end
end
