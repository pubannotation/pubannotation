class RemoveEmbeddingsJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(project, options)
		analysis = if project.analysis.present?
			JSON.parse project.analysis, symbolize_names: true
		else
			nil
		end

		embeddings = analysis.present? ? analysis[:embeddings] : []

		if @job
			prepare_progress_record(embeddings.length)
		end

		ActiveRecord::Base.transaction do
			embeddings.each_with_index do |e, i|
				denotation = Denotation.find_a_denotation(project, e[:sourcedb], e[:sourceid], e[:embedded])
				denotation.destroy
			ensure
				if @job
					@job.update_attribute(:num_dones, i + 1)
					check_suspend_flag
				end
			end
		end
	end

	def job_name
		'Remove embedded annotations'
	end
end
