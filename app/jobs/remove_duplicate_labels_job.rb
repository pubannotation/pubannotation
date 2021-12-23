class RemoveDuplicateLabelsJob < ApplicationJob
	queue_as :low_priority

	def perform(project, options)
		order = options[:order]
		orderh = {}
		order.each_with_index{|l, i| orderh[l] = i}

		analysis = if project.analysis.present?
			JSON.parse project.analysis, symbolize_names: true
		else
			nil
		end

		duplabels = analysis.present? ? analysis[:duplabels] : []

		if @job
			prepare_progress_record(duplabels.length)
		end

		ActiveRecord::Base.transaction do
			duplabels.each_with_index do |e, i|
				denotations = e[:ids].map{|id| Denotation.find_a_denotation(project, e[:sourcedb], e[:sourceid], id)}
				denotations.sort!{|a, b| orderh[a.obj] <=> orderh[b.obj]}
				select = denotations.shift
				denotations.each{|d| d.destroy}
			ensure
				if @job
					@job.update_attribute(:num_dones, i + 1)
					check_suspend_flag
				end
			end
		end
	end

	def job_name
		'Remove duplicate labels'
	end
end
