class ImportAnnotationsJob < ApplicationJob
	queue_as :general

	def perform(project, source_project_id, options = {})
		shared_docs_ids = if options[:mode] == 'skip'
			ActiveRecord::Base.connection.exec_query("SELECT doc_id FROM project_docs WHERE project_id=#{source_project_id} INTERSECT SELECT doc_id FROM project_docs WHERE project_id=#{project.id} AND denotations_num=0").pluck("doc_id")
		else
			ActiveRecord::Base.connection.exec_query("SELECT doc_id FROM project_docs WHERE project_id=#{source_project_id} INTERSECT SELECT doc_id FROM project_docs WHERE project_id=#{project.id}").pluck("doc_id")
		end

		raise "Importing annotations for more than 1M documents is prohibited for a performance issue." if shared_docs_ids.length > 1000000
		raise "There is no shared document in the two projects." if shared_docs_ids.empty?

		source_project = Project.find(source_project_id)
		destin_project = project

		prepare_progress_record(shared_docs_ids.length)

		shared_docs_ids.each do |doc_id|
			begin
				annotations = doc.hannotations(source_project, nil, nil)
				messages = destin_project.save_annotations!(annotations, doc, options)
				messages.each{|m| @job&.add_message m}
			rescue => e
				@job&.add_message sourcedb: annotations[:sourcedb],
								  sourceid: annotations[:sourceid],
								  body: e.message
			end
			@job&.increment!(:num_dones)
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