class UptodateDocsJob < ApplicationJob
	queue_as :low_priority

	def perform(project)
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
				unless r[:messages].empty?
					r[:messages].each do |m|
						message = if m.class == String
							{body: m[0 ... 200]}
						elsif m.class == Hash
							_sourcedb = m[:sourcedb] || ''
							_sourceid = m[:sourceid] || ''
							_body = m[:body] || ''
							{sourcedb: _sourcedb[0 ... 200], sourceid: _sourceid[0 ... 200], body: _body[0 ... 200]}
						else
							{body: "Unknown message: #{m}"[0 ... 200]}
						end
						@job.messages << Message.create(message)
					end
				end
				hdocs_sequenced = r[:docs]
				hdocs_sequenced.each do |hdoc|
					doc = Doc.where(sourcedb:sourcedb, sourceid:hdoc[:sourceid]).first
					Doc.uptodate(doc, hdoc)
					@job.update_attribute(:num_dones, num += 1) if @job
				rescue => e
					if @job
						@job.messages << Message.create({sourcedb: hdoc[:sourcedb], sourceid: hdoc[:sourceid], body: e.message})
					else
						raise e.message
					end
				end
			rescue => e
				@job.messages << Message.create({sourcedb: sourcedb, sourceid: sids.join(", ")[0 ... 200], body: e.message[0 ... 200]})
			end
		end
	end
end
