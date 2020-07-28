class DeleteAllDocsFromProjectJob < Struct.new(:project)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, 1) if @job
		@job.update_attribute(:num_dones, 0) if @job

		project.delete_docs

		delayed_job = Delayed::Job.enqueue UpdateElasticsearchIndexJob.new(project), queue: :general
		Job.create({name:'Update text search index', project_id:project.id, delayed_job_id:delayed_job.id})

		@job.update_attribute(:num_dones, 1) if @job
		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
	end
end
