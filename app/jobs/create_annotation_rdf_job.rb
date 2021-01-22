class CreateAnnotationRdfJob < Struct.new(:project)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, project.docs.count)
			@job.update_attribute(:num_dones, 0)
		end

		project.create_annotations_RDF do |i|
			if @job
				@job.update_attribute(:num_dones, i + 1) 
			end
		end
	end

end
