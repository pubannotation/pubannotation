class DeleteAllDocsFromProjectJob < ApplicationJob
	queue_as :general

	def perform(project)
		if @job
			prepare_progress_record(1)
		end

		ActiveRecord::Base.transaction do
			# 1. delete all the annotations
			project.delete_annotations if project.denotations_num > 0

			if project.docs.exists?
				# 2. mark the docs to be deleted, and decrement projects_num
				ActiveRecord::Base.connection.exec_query(
					"
						UPDATE docs
						SET projects_num = projects_num - 1, flag = true
						WHERE docs.id
						IN (
							SELECT project_docs.doc_id
							FROM project_docs
							WHERE project_docs.project_id = #{project.id}
						)
					"
				)

				# 3. delete the association
				ActiveRecord::Base.connection.exec_query("DELETE FROM project_docs WHERE project_id = #{project.id}")

				# 4. destroy orphan custom documents
				wclause = "sourcedb LIKE '%#{Doc::UserSourcedbSeparator}#{project.user.username}' AND projects_num = 0"
				Doc.where(wclause).ids.each do |doc_id|
					Indexer.perform_later(nil, :delete, doc_id)
				end
				ActiveRecord::Base.connection.exec_query("DELETE FROM docs WHERE " + wclause)

				# 5. update ES index
				Doc.where(flag: true).ids.each{|doc_id| Indexer.perform_later(nil, :update, doc_id)}
				# Doc.__elasticsearch__.import query: -> { where(flag: true) }
			end
		end

		# 6. clear flags
		ActiveRecord::Base.connection.exec_query('UPDATE docs SET flag = false WHERE flag = true')

		@job.update_attribute(:num_dones, 1) if @job
		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
	end

	def job_name
		'Delete all docs'
	end
end
