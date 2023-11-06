class ImportDocsJob < ApplicationJob
	queue_as :general

	def perform(project, source_project)
		docids = source_project.docs.pluck(:id) - project.docs.pluck(:id)

		if docids.empty?
			@job&.add_message body: "Importing docs from the project '#{source_project.name}' is skipped due to duplication."
		else
			num_source_docs = source_project.docs.count
			num_skip = num_source_docs - docids.length
			@job&.add_message body: "Importing #{num_skip} doc(s) is skipped due to duplication." if num_skip > 0
		end

		prepare_progress_record(docids.length)

		sourcedb_h = {}
		docids.each_with_index do |id, i|
			doc = Doc.find(id)
			sourcedb_h[doc.sourcedb] = true
			doc.projects << project
			@job&.update_attribute(:num_dones, i + 1)
			check_suspend_flag
		end

		unless sourcedb_h.empty?
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			sourcedb_h.each_key do |sdb|
				ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")
			end
		end
	end

	def job_name
		'Import docs to project'
	end
end
