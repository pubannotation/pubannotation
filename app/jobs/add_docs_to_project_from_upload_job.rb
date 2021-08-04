class AddDocsToProjectFromUploadJob < ApplicationJob
	queue_as :general

	def perform(sourcedb, filepath, project)
		count = %x{wc -l #{filepath}}.split.first.to_i

		if @job
			prepare_progress_record(count)
		end

		@total_num_added = 0
		@total_num_sequenced = 0
		@total_num_existed = 0

		ids = []
		File.foreach(filepath).with_index do |line, i|
			line.chomp! && line.strip!
			line.sub!(/^PMC/, '')
			ids << line unless line.empty?

			if ids.length >= 1000
				add_docs(project, sourcedb, ids)
				ids.clear
			end

			if @job
				@job.update_attribute(:num_dones, i + 1)
				check_suspend_flag
			end
		end

		add_docs(project, sourcedb, ids)

		if @total_num_sequenced > 0
			ActionController::Base.new.expire_fragment('sourcedb_counts')
			ActionController::Base.new.expire_fragment('docs_count')
		end

		if @total_num_added > 0
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			ActionController::Base.new.expire_fragment("count_#{sourcedb}_#{project.name}")
		end

		File.unlink(filepath)
	end

	private

	def add_docs(project, sourcedb, ids)
		num_added, num_sequenced, num_existed, messages = begin
			project.add_docs(sourcedb, ids)
		rescue => e
			if @job
				@job.messages << Message.create({sourcedb: sourcedb, sourceid: "#{ids.first} - #{ids.last}", body: e.message})
			end
			[0, 0, 0, []]
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

		messages.each do |message|
			if @job
				@job.messages << (message.class == Hash ? Message.create(message) : Message.create({body: message}))
			end
		end
	end
end
