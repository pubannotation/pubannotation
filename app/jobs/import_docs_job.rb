class ImportDocsJob < ApplicationJob
	queue_as :general
	BatchSize = 100

	def perform(project, sproject_id)
		total_num = ProjectDoc.where(project_id:sproject_id).count
		prepare_progress_record(total_num)

		i = 0
		sum_imported = 0
		while (ids = get_next_batch(sproject_id, i)).present?
			# to avoid duplicate import
			ids_duplicate = ProjectDoc.where(project_id:project.id, doc_id:ids).pluck(:doc_id)
			ids_to_import = ids - ids_duplicate

			if ids_to_import.present?
				# the 'import' method does not utilize callbacks and skips uniqueness validation
				r = ProjectDoc.import [:project_id, :doc_id], ids_to_import.map{|doc_id| [project.id, doc_id]}, on_duplicate_key_ignore:true
				raise "failed in importing #{ids_to_import.count - r.ids.count} documents" unless r.ids.count == ids_to_import.count
				ActiveRecord::Base.connection.exec_query "UPDATE docs SET projects_num = projects_num + 1 WHERE id IN (#{ids_to_import.join(', ')})"
				ids_to_import.each{|doc_id| Indexer.perform_later(nil, :update, doc_id)}

				sum_imported += ids_to_import.count
			end

			# to take care of the project_num attribute and elasticsearch index of each imported document

			@job.update_attribute(:num_dones, BatchSize * i) if @job
			check_suspend_flag
			i += 1
		end
		@job.update_attribute(:num_dones, total_num) if @job

		num_skip = sum_imported - total_num
		if @job && num_skip > 0
			@job.add_message body: "#{num_skip} docs were already existing."
		end

		if sum_imported > 0
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			ActionController::Base.new.expire_fragment(/count_.*_#{project.name}/)
		end
	end

	def get_next_batch(sproject_id, i)
		ProjectDoc.where(project_id:sproject_id).limit(BatchSize).offset(i * BatchSize).pluck(:doc_id)
	end

	def job_name
		'Import docs to project'
	end
end
