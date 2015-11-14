module JobsHelper
	def state(job)
		if job.begun_at.nil?
			'Waiting'
		elsif job.ended_at.nil?
			'Running'
		else
			'Finished'
		end
	end
end
