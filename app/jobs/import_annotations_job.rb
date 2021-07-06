class ImportAnnotationsJob < ApplicationJob
	queue_as :general

	def perform(project, source_project)
		docs = project.docs & source_project.docs

		prepare_progress_record(docs.length)

		docs.each_with_index do |doc, i|
			begin
				annotations = doc.hannotations(source_project)
				messages = project.save_annotations!(annotations, doc)
				messages.each{|m| @job.messages << Message.create(m)}
			rescue => e
				@job.messages << Message.create({sourcedb: annotations[:sourcedb], sourceid: annotations[:sourceid], divid: annotations[:divid], body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
			check_suspend_flag
		end
	end

	def job_name
		"Import annotations from #{resource_name}"
	end

	private

	def resource_name
		self.arguments[1].name
	end
end
