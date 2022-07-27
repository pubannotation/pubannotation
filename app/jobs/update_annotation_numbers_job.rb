class UpdateAnnotationNumbersJob < ApplicationJob
	queue_as :low_priority

	def perform
		queries = [
			{name: "update #denotations of every doc", sql: "update docs set (denotations_num) = (select count(*) from denotations where denotations.doc_id = docs.id)"},
			{name: "update #relations of every doc", sql:"update docs set (relations_num) = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = docs.id)"},
			{name: "update #modifications of every doc", sql: "update docs set (modifications_num) = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = docs.id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=docs.id))"},
			{name: "update #denotations of every project_doc", sql:"update project_docs set (denotations_num) = (select count(*) from denotations where denotations.doc_id=project_docs.doc_id and denotations.project_id=project_docs.project_id)"},
			{name: "update #relations of every project_doc", sql:"update project_docs set (relations_num) = (select count(*) from relations inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotation' where denotations.doc_id = project_docs.doc_id and relations.project_id=project_docs.project_id)"},
			{name: "update #modifications of every project_doc", sql:"update project_docs set (modifications_num) = ((select count(*) from modifications inner join denotations on modifications.obj_id=denotations.id and modifications.obj_type='Denotation' where denotations.doc_id = project_docs.id and modifications.project_id=project_docs.project_id) + (select count(*) from modifications inner join relations on modifications.obj_id=relations.id and modifications.obj_type='Relation' inner join denotations on relations.subj_id=denotations.id and relations.subj_type='Denotations' where denotations.doc_id=project_docs.doc_id and modifications.project_id=project_docs.project_id))"}
		]

		prepare_progress_record(queries.count)

		queries.each_with_index do |query, i|
			begin
				ActiveRecord::Base.connection.execute query[:sql]
			rescue => e
				@job.add_message body: "executions of #{query[:name]} failed."
			ensure
				if @job
					@job.update_attribute(:num_dones, i + 1)
					check_suspend_flag
				end
			end
		end
	end

	def job_name
		"Update annotation numbers of each document"
	end

	private

	def organization_jobs
		Project.find_by_name('system-maintenance').jobs
	end
end
