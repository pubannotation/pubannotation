class ObtainDocAnnotationsJob < ApplicationJob
	queue_as :general

	def perform(project, docid, annotator, options)
		doc = Doc.find(docid)
		doc.set_ascii_body if options[:encoding].present? && options[:encoding] == 'ascii'
		max_text_size = annotator.async_protocol ? Annotator::MaxTextAsync : Annotator::MaxTextSync
		slices = doc.get_slices(max_text_size, options[:span])

		if @job
			if slices.length > 1
				@job.add_message sourcedb:doc.sourcedb,
												 sourceid:doc.sourceid,
												 body: "The document was too big to be processed at once (#{number_with_delimiter(doc.body.length)} > #{number_with_delimiter(max_text_size)}). For proceding, it was divided into #{slices.length} slices."
			end
			prepare_progress_record(slices.length)
		end

		slices.each_with_index do |slice, i|
			timer_start = Time.now
			slice_text = doc.get_text(slice)
			text_length = slice_text.length

			annotations = annotator.obtain_annotations([{text:slice_text, sourcedb:doc.sourcedb, sourceid:doc.sourceid}]).first
			ttime = Time.now - timer_start

			timer_start = Time.now
			messages = project.save_annotations!(annotations, doc, options.merge(span:slice))
			messages.each do |m|
				@job.add_message m
			end
			stime = Time.now - timer_start

			annotations_num = annotations[:denotations].length
			if @job && options[:debug]
				@job.add_message body: "Annotation obtained, sync (ttime:#{ttime}, stime:#{stime}, length:#{text_length}, num:#{annotations_num})"
			end

		rescue RestClient::ExceptionWithResponse => e
			if e.response.nil?
				raise RuntimeError, e.message
			else
				if e.response.code == 201
					retrieve_and_store(e.response.headers[:location], annotator, project, options)
				elsif e.response.code == 503
					raise RuntimeError, "Service unavailable"
				elsif e.response.code == 404
					raise RuntimeError, "The annotation server does not know the path."
				else
					raise RuntimeError, "Received the following message from the server: #{e.message} "
				end
			end
		rescue => e
			if @job
				@job.add_message sourcedb:doc.sourcedb,
												 sourceid:doc.sourceid,
												 body: e.message
			else
				raise RuntimeError, e.message
			end
		ensure
			if @job
				@job.update_attribute(:num_dones, i + 1)
				check_suspend_flag
			end
		end
	end

	def job_name
		"Obtain annotations for a document: #{resource_name}"
	end

	private

	def retrieve_and_store(url, annotator, project, options)
		status = annotator.make_request(:get, url)
		while ['IN_QUEUE', 'IN_PROGRESS'].include? status[:status]
			case status[:status]
			when 'IN_QUEUE'
				if Time.now - status[:submitted_at].to_time > Annotator::MaxWaitInQueueBatch
					raise RuntimeError, "The task is terminated because it has been waiting for more than #{Annotator::MaxWaitInQueueBatch} in the queue."
				end
				etr = status[:ETR]
				sleep(etr || Annotator::MaxWaitInQueue)
			when 'IN_PROGRESS'
				if (Time.now - status[:started_at].to_time) > Annotator::MaxWaitInProcessingBatch
					raise RuntimeError, "The task is terminated because it has been in processing for more than #{Annotator::MaxWaitInProcessingBatch}."
				end
				etr = status[:ETR]
				sleep(etr || Annotator::MaxWaitInQueue)
			end
			status = annotator.make_request(:get, url)
		end

		case status[:status]
		when 'DONE'
			result = annotator.make_request(:get, status[:result_location])
			annotations = result.class == Array ? result.first : result
			text_length = annotations[:text].length
			annotations_num = annotations[:denotations].length

			timer_start = Time.now
			annotations = Annotation.normalize!(annotations)
			doc = Doc.find_by_sourcedb_and_sourceid(annotations[:sourcedb], annotations[:sourceid])
			stime = Time.now - timer_start
			messages = project.save_annotations!(annotations, doc, options)
			messages.each do |m|
				@job.add_message m
			end

			if @job && options[:debug]
				ptime = status[:finished_at].to_time - status[:started_at].to_time
				qtime = status[:started_at].to_time - status[:submitted_at].to_time
				@job.add_message body: "Annotation received, async (qtime:#{qtime}, ptime:#{ptime}, stime:#{stime}, length:#{text_length}, num:#{annotations_num})"
			end
		when 'ERROR'
			raise RuntimeError, "The annotation server issued an error message: #{status[:error_message]}."
		else
			raise RuntimeError, "The annotation server reported an unknown status of the annotation task: #{status[:status]}."
		end

	rescue => e
		if @job
			@job.add_message body: e.message
		else
			raise ArgumentError, e.message
		end
	end

	def resource_name
		self.arguments[2].name
	end
end
