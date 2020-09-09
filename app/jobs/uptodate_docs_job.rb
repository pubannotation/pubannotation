class UptodateDocsJob < Struct.new(:project)
	include StateManagement

	def perform
		batch_num = Sequencer::MAX_NUM_ID
		sourcedbs = project.docs.pluck(:sourcedb).uniq
		count_sourceids = sourcedbs.reduce(0) do |sum, sourcedb|
			sum + project.docs.where(sourcedb:sourcedb).pluck(:sourceid).uniq.count
		end

		if @job
			@job.update_attribute(:num_items, count_sourceids)
			@job.update_attribute(:num_dones, 0)
		end

		num = 0
		sourcedbs.each do |sourcedb|
			sourceids = project.docs.where(sourcedb:sourcedb).pluck(:sourceid).uniq

			sourceids.each_slice(batch_num).each do |sids|
				r = Doc.sequence_docs(sourcedb, sids)
				@job.messages += r[:messages] unless r[:messages].empty?
				hdocs_sequenced = r[:docs]
				hdocs_sequenced.each do |hdoc|
					divs = Doc.where(sourcedb:sourcedb, sourceid:hdoc[:sourceid]).order(:serial)
					Doc.uptodate(divs, hdoc)
					@job.update_attribute(:num_dones, num += 1) if @job
				rescue => e
					if @job
						@job.messages << Message.create({sourcedb: hdoc[:sourcedb], sourceid: hdoc[:sourceid], body: e.message})
					else
						raise e.message
					end
				end
			end
		end
	end
end
