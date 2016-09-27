class DeleteAllDocsFromProjectJob < Struct.new(:project)
	include StateManagement

	def perform
    @job.update_attribute(:num_items, 1)
    @job.update_attribute(:num_dones, 0)
    project.delete_docs
    @job.update_attribute(:num_dones, 1)
		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
  end
end
