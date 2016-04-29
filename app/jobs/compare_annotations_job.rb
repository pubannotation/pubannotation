require 'fileutils'
include AnnotationsHelper

class CompareAnnotationsJob < Struct.new(:project, :project_ref)
	include StateManagement

	def perform
    @job.update_attribute(:num_items, 1)
    @job.update_attribute(:num_dones, 0)
    project.create_comparison(project_ref)
   	@job.update_attribute(:num_dones, 1)
	end
end
