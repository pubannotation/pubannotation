class ObtainAnnotationsJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(project, filepath, annotator, options)
		count = %x{wc -l #{filepath}}.split.first.to_i

		if @job
			prepare_progress_record(count)
		end

		# for asynchronous protocol
		@annotation_tasks_queue = []
		@max_text_size = annotator.max_text_size || (annotator.async_protocol ? Annotator::MaxTextAsync : Annotator::MaxTextSync)
		single_doc_processing_p = annotator.single_doc_processing?
		skip_interval = Annotator::SkipInterval

		docs = []
		docs_size = 0
		File.foreach(filepath) do |line|
			docid = line.chomp.strip
			doc = Doc.find(docid)
			doc.set_ascii_body if options[:encoding] == 'ascii'
			doc_length = doc.body.length

			if docs.present? && (single_doc_processing_p || (docs_size + doc_length) > @max_text_size)
				begin
					if docs.length == 1 && docs.first.body.length > @max_text_size
						doc1 = docs.first
						slices = doc1.get_slices(@max_text_size)
						if @job
							count = @job.num_items + slices.length - 1
							@job.update_attribute(:num_items, count)
							if slices.length > 1
								@job.add_message sourcedb:doc1.sourcedb,
																 sourceid:doc1.sourceid,
																 body: "The document was too big to be processed at once (#{number_with_delimiter(doc1.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."
							end
						end
						# delete all the annotations here for a better performance
						project.delete_doc_annotations(doc1) if options[:mode] == 'replace'
						slices.each do |slice|
							begin
							  make_request_batch(project, docs, annotator, options.merge(span:slice))
							rescue RuntimeError => e
								if e.class == Exceptions::JobSuspendError
									raise e
								end
								if @job
									@job.add_message sourcedb:doc1.sourcedb,
																	 sourceid:doc1.sourceid,
																	 body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
								end
							rescue => e
								if e.class == Exceptions::JobSuspendError
									raise e
								end
								if @job
									@job.add_message sourcedb:doc1.sourcedb,
																	 sourceid:doc1.sourceid,
																	 body: "Error while processing the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
								end
							end
						end
					else
						make_request_batch(project, docs, annotator, options)
					end
				rescue => e
					if e.class == Exceptions::JobSuspendError
						raise e
					elsif @job
						if docs.length < 10
							docs.each do |doc|
								@job.add_message sourcedb: doc.sourcedb,
																 sourceid: doc.sourceid,
																 body: "Could not obtain annotations: #{exception_message(e)}"
							end
						else
							@job.add_message body: "Could not obtain annotations for #{docs.length} docs: #{exception_message(e)}"
						end
					else
						raise e
					end
				ensure
					docs.clear
					docs_size = 0
				end
			end

			docs << doc
			docs_size += doc_length

			process_tasks_queue(project, annotator, options) unless @annotation_tasks_queue.empty?
		rescue RuntimeError => e
			if e.class == Exceptions::JobSuspendError
				raise e
			elsif @job
				if docs.length < 10
					docs.each do |doc|
						@job.add_message sourcedb: doc.sourcedb,
														 sourceid: doc.sourceid,
														 body: "Runtime error: #{exception_message(e)}"
					end
				else
					@job.add_message body: "Runtime error while processing #{docs.length} docs: #{exception_message(e)}"
				end
			else
				raise e
			end
		end

		if docs.present?
			begin
				if docs.length == 1 && docs.first.body.length > @max_text_size
					doc1 = docs.first
					slices = doc1.get_slices(@max_text_size)
					if @job
						count = @job.num_items + slices.length - 1
						@job.update_attribute(:num_items, count)
						if slices.length > 1
							@job.add_message sourcedb:doc1.sourcedb,
															 sourceid:doc1.sourceid,
															 body: "The document was too big to be processed at once (#{number_with_delimiter(doc1.body.length)} > #{number_with_delimiter(@max_text_size)}). For proceding, it was divided into #{slices.length} slices."
						end
					end
					# delete all the annotations here for a better performance
					project.delete_doc_annotations(doc1) if options[:mode] == 'replace'
					slices.each do |slice|
						make_request_batch(project, docs, annotator, options.merge(span:slice))
					rescue RuntimeError => e
						if e.class == Exceptions::JobSuspendError
							raise e
						elsif @job
							@job.add_message sourcedb:doc1.sourcedb,
															 sourceid:doc1.sourceid,
															 body: "Could not obtain for the slice (#{slice[:begin]}, #{slice[:end]}): #{exception_message(e)}"
						else
							raise e
						end
					end
				else
					make_request_batch(project, docs, annotator, options)
				end
			end
		end

		until @annotation_tasks_queue.empty?
			begin
				process_tasks_queue(project, annotator, options)
				sleep(skip_interval) unless @annotation_tasks_queue.empty?
			rescue => e
				if e.class == Exceptions::JobSuspendError
					raise e
				elsif @job
					@job.add_message body: exception_message(e)
				else
					raise e
				end
			end
		end

		File.unlink(filepath)
	end

	def job_name
		"Obtain annotations: #{resource_name}"
	end

private

	def make_request_batch(project, docs, annotator, options)
		hdocs = if options[:span].present?
			doc = docs.first
			[{text:doc.get_text(options[:span]), sourcedb:doc.sourcedb, sourceid:doc.sourceid}]
		else
			docs.map{|d| d.hdoc}
		end

		timer_start = Time.now
		annotations_col = annotator.obtain_annotations(hdocs)
		ttime = Time.now - timer_start

		## In case of synchronous protocol
		text_length = annotations_col.reduce(0){|sum, annotations| sum += annotations[:text].length}
		timer_start = Time.now
		if options[:span].present?
			messages = project.save_annotations!(annotations_col.first, docs.first, options)
			messages.each do |m|
				m = {body: m} if m.class == String
				@job.add_message m
			end
		else
			StoreAnnotationsCollection.new(project, annotations_col, options, @job).call.join
		end
		stime = Time.now - timer_start

		if @job
			num = annotations_col.reduce(0){|sum, annotations| sum += annotations[:denotations].length}
			if options[:debug]
				@job.add_message body: "Annotation obtained, sync (ttime:#{ttime}, stime:#{stime}, length:#{text_length}, num:#{num})"
			end
			@job.increment!(:num_dones, docs.length)
			check_suspend_flag
		end
	rescue RestClient::ServiceUnavailable => e
		if @service_unavailable_begins_at.present?
			raise e if (Time.now - @service_unavailable_begins_at) > 3600
		else
			@service_unavailable_begins_at = Time.now
		end
		retry_after = e.response.headers[:retry_after].to_i if e.response.headers[:retry_after].present?
		if @annotation_tasks_queue.empty?
			sleep(retry_after || 5)
		else
			process_tasks_queue(project, annotator, options)
		end
		retry
	rescue RestClient::ExceptionWithResponse => e
		if e.response.present? && e.response.respond_to?(:code)
			case e.response.code
			when 201
				## In case of asynchronous protocol
				task = {url: e.response.headers[:location]}
				task.merge!(span:options[:span], docid:docs.first.id) if options[:span].present?
				@annotation_tasks_queue << task
				@service_unavailable_begins_at = nil
			else
				raise e
			end
		else
			raise e
		end
	end

	def process_tasks_queue(project, annotator, options)
		@annotation_tasks_queue.each do |task|
			status = annotator.make_request(:get, task[:url])
			case status[:status]
			when 'DONE'
				task[:delme] = true
				result = annotator.make_request(:get, status[:result_location])
				annotations_col = (result.class == Array) ? result : [result]
				annotations_col.each_with_index do |annotations, i|
					raise RuntimeError, "annotation result is not a valid JSON object." unless annotations.class == Hash
					AnnotationUtils.normalize!(annotations)
					annotator.annotations_transform!(annotations)
				rescue => e
					if @job
						@job.add_message sourcedb: annotations[:sourcedb],
														 sourceid: annotations[:sourceid],
														 body: exception_message(e)
					else
						raise e
					end
				end

				timer_start = Time.now
				if task[:span].present?
					messages = project.save_annotations!(annotations_col.first, Doc.find(task[:docid]), options.merge(span:task[:span]))
					messages.each do |m|
						m = {body: m} if m.class == String
						@job.add_message m
					end
				else
					StoreAnnotationsCollection.new(project, annotations_col, options, @job).call.join
				end

				stime = Time.now - timer_start

				if @job
					ptime = status[:finished_at].to_time - status[:started_at].to_time
					qtime = status[:started_at].to_time - status[:submitted_at].to_time
					length = annotations_col.reduce(0){|sum, annotations| sum += annotations[:text].length}
					num = annotations_col.reduce(0){|sum, annotations| sum += annotations[:denotations].length}
					if options[:debug]
						@job.add_message body: "Annotation obtained, async (qtime:#{qtime}, ptime:#{ptime}, stime:#{stime}, length:#{length}, num:#{num})"
					end
					@job.increment!(:num_dones, annotations_col.length)
					check_suspend_flag
				end
			when 'ERROR'
				task[:delme] = true
				raise RuntimeError, "The annotation server issued an error message: #{status[:error_message]}."
			when 'IN_QUEUE'
				if Time.now - status[:submitted_at].to_time > Annotator::MaxWaitInQueueBatch
					message = "The task is terminated because an annotation task has been waiting for more than #{Annotator::MaxWaitInQueue} seconds in the queue - submitted_at: #{status[:submitted_at]}, terminated_at: #{Time.now}"
					if @job
						if task[:span].present?
							d = Doc.find(task[:docid])
							@job.add_message sourcedb:d.sourcedb,
															 sourceid:d.sourceid,
															 body: message
						else
							@job.add_message body: message
						end
						exit
					else
						raise message
					end
				end
			when 'IN_PROGRESS'
				if Time.now - status[:started_at].to_time > Annotator::MaxWaitInProcessingBatch
					message = "The task is terminated because an annotation task has been in processing for more than #{Annotator::MaxWaitInProcessing} seconds - started_at: #{status[:started_at]}, terminated_at: #{Time.now}."
					if @job
						if task[:span].present?
							d = Doc.find(task[:docid])
							@job.add_message sourcedb: d.sourcedb,
															 sourceid: d.sourceid,
															 body: message
						else
							@job.add_message body: message
						end
						exit
					else
						raise message
					end
				end
			else
				task[:delme] = true
				raise RuntimeError, "The annotation server reported an unknown status of the annotation task: #{status[:status]}."
			end
		end
	ensure
		@annotation_tasks_queue.delete_if{|task| task[:delme]}
	end

	def exception_message(exception)
		exception.message
	rescue => e
		"exception message inaccessible:\n#{exception}:\n#{exception.backtrace.join("\n")}"
	end

	def resource_name
		self.arguments[2].name
	end
end
