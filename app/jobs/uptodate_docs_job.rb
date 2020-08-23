class UptodateDocsJob < Struct.new(:project)
	include StateManagement

	def perform
		batch_num = Sequencer::MAX_NUM_ID
		sourcedbs = project.docs.pluck(:sourcedb).uniq

		sourcedbs.each do |sourcedb|
			sourceids = project.docs.where(sourcedb:sourcedb).pluck(:sourceid).uniq

			if @job
				@job.update_attribute(:num_items, sourceids.length)
				@job.update_attribute(:num_dones, 0)
			end
			num = 0

			sourceids.each_slice(batch_num).each do |sids|
				begin
					r = Doc.sequence_docs(sourcedb, sids)
					@job.messages += r[:messages] unless r[:messages].empty?
					hdocs_sequenced = r[:docs]
					hdocs_sequenced.each do |hdoc|
						divs = Doc.where(sourcedb:sourcedb, sourceid:hdoc[:sourceid]).order(:serial)
						Doc.uptodate(divs, hdoc)
					end
				rescue => e
					if @job
						@job.messages << Message.create({body: e.message})
					else
						raise e.message
					end
				end
				@job.update_attribute(:num_dones, num += sids.length) if @job
			end
		end
	end
end
