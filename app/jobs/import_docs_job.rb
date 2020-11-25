class ImportDocsJob < Struct.new(:filepath, :project)
	include StateManagement

	def perform
		count = %x{wc -l #{filepath}}.split.first.to_i

		@job.update_attribute(:num_items, count)
		@job.update_attribute(:num_dones, 0)

		sourcedb_h = {}
		File.foreach(filepath).with_index do |id, i|
			doc = Doc.find(id.chomp)
			sourcedb_h[doc.sourcedb] = true
			doc.projects << project
			@job.update_attribute(:num_dones, i + 1)
		end

		unless sourcedb_h.empty?
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			sourcedb_h.each_key{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
		end
	end
end
