class UpdateElasticsearchIndexJob < Struct.new(:project)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, 1) if @job
		@job.update_attribute(:num_dones, 0) if @job
		project.update_es_index
		@job.update_attribute(:num_dones, 1) if @job
	end
end
