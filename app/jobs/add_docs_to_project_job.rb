class AddDocsToProjectJob < Struct.new(:docspecs, :project)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, docspecs.length)
			@job.update_attribute(:num_dones, 0)
		end

		@total_num_added = 0
		@total_num_sequenced = 0
		@total_num_existed = 0

		docspecs_group_by_sourcedb = docspecs.group_by{|docspec| docspec[:sourcedb]}
		i = 0
		docspecs_group_by_sourcedb.each do |sourcedb, docspecs|
			ids = docspecs.map{|docspec| docspec[:sourceid]}
			num_added, num_sequenced, num_existed, messages = begin
				project.add_docs(sourcedb, ids)
			rescue => e
				if @job
					@job.messages << Message.create({sourcedb: sourcedb, sourceid: "#{ids.first} - #{ids.last}", body: e.message})
					[0, 0, 0, []]
				else
					raise e
				end
			end

			@total_num_added += num_added
			@total_num_sequenced += num_sequenced
			@total_num_existed += num_existed

			@message_docs_existed.update_attribute(:body, "#{@total_num_existed} doc(s) existed. #{@total_num_added} doc(s) added.") if @message_docs_existed

			if @total_num_existed > 0 && !defined?(@message_docs_existed)
				@message_docs_existed = Message.create({body: "#{@total_num_existed} doc(s) existed. #{@total_num_added} doc(s) added."})
				if @job
					@job.messages << @message_docs_existed
				end
			end

			unless messages.empty?
				if @job
					messages.each do |message|
						@job.messages << (message.class == Hash ? Message.create(message) : Message.create({body: message}))
					end
				else
					raise messages.join("\n")
				end
			end

			i += docspecs.length
			@job.update_attribute(:num_dones, i) if @job
		end

		if @total_num_sequenced > 0
			ActionController::Base.new.expire_fragment('sourcedb_counts')
			ActionController::Base.new.expire_fragment('docs_count')
		end

		sourcedbs = docspecs_group_by_sourcedb.keys
    unless sourcedbs.empty?
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			sourcedbs.uniq.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
		end
	end
end
