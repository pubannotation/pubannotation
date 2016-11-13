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

	def time_duration(from, to)
		t = to - from
		mm, ss = t.divmod(60)
		hh, mm = mm.divmod(60)
		dd, hh = hh.divmod(24)
		words  = ""
		words += "#{dd}d " if dd > 0
		words += "#{hh}h " if hh > 0
		words += "#{mm}m " if mm > 0
		words += "#{'%d' % ss}s"
	end
end
