class ImportAnnotationsJob < ApplicationJob
	queue_as :general

	def perform(project, source_project_names, options = {})
		source_projects = source_project_names.map{|name| Project.find_by_name(name)}.compact

		destin_docs = project.docs
		num_docs = source_projects.map{|source_project| (source_project.docs & destin_docs).length}.reduce(:+)
		prepare_progress_record(num_docs)

		source_projects.each{|source_project|	import_annotations(source_project, project, options)}
	end

	def import_annotations(source_project, destin_project, options = {})
		docs = source_project.docs & destin_project.docs

		docs.each do |doc|
			begin
				annotations = doc.hannotations(source_project, nil, nil)
				messages = destin_project.save_annotations!(annotations, doc, options)
				messages.each{|m| @job.add_message m}
			rescue => e
				@job.add_message sourcedb: annotations[:sourcedb],
												 sourceid: annotations[:sourceid],
												 body: e.message
			end
			@job.increment!(:num_dones)
			check_suspend_flag
		end
	end

	def job_name
		"Import annotations from the projects, #{resource_name}"
	end

	private

	def resource_name
		self.arguments[1].join(', ')
	end
end
