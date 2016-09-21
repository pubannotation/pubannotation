class DestroyProjectJob < Struct.new(:project)
	include StateManagement

	def perform
	    project.jobs.each do |job|
	      job.destroy_if_not_running
	    end
	    project.delete_annotations
		project.destroy
	end
end
