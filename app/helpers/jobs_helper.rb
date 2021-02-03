module JobsHelper
	def time_duration(duration)
		mm, ss = duration.divmod(60)
		hh, mm = mm.divmod(60)
		dd, hh = hh.divmod(24)
		words  = ""
		words += "#{dd}d " if dd > 0
		words += "#{hh}h " if hh > 0
		words += "#{mm}m " if mm > 0
		words += "#{'%d' % ss}s"
	end
end
