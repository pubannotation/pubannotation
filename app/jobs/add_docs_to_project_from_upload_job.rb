class AddDocsToProjectFromUploadJob < Struct.new(:sourcedb, :filepath, :project)
	include StateManagement

	def perform
		count = %x{wc -l #{filepath}}.split.first.to_i

		@job.update_attribute(:num_items, count)
		@job.update_attribute(:num_dones, 0)

		ids = []
		File.foreach(filepath) do |line|
			line.chomp!.strip!
			ids << line unless line.empty?

			if ids.length >= 500
				add_docs(sourcedb, ids)
				ids.clear
			end
	  end

		add_docs(sourcedb, ids)

		ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
		ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
		ActionController::Base.new.expire_fragment("count_#{sourcedb}_#{project.name}")

		File.unlink(filepath)
	end

	private

	def add_docs(sourcedb, ids)
		added, messages, num_docs_existed = begin
			project.add_docs(sourcedb, ids)
    rescue => e
			@job.messages << Message.create({sourcedb: sourcedb, sourceid: "#{ids.first} - #{ids.last}", body: e.message})
			[[], [], 0]
		end

		if num_docs_existed > 0
			if @total_num_docs_existed
				@total_num_docs_existed += num_docs_existed
				@message_existing_docs.update_attribute(:body, "#{@total_num_docs_existed} doc(s) already existed.")
			else
				@total_num_docs_existed = num_docs_existed
				@message_existing_docs = Message.create({body: "#{@total_num_docs_existed} doc(s) already existed."})
				@job.messages << @message_existing_docs
			end
		end

		messages.each{|message| @job.messages << Message.create({body: message})}
		num_added_docs = added.map{|d| d[:sourceid]}.uniq.length
    @job.update_attribute(:num_dones, @job.num_dones + num_added_docs)
	end
end
