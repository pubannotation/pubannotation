class ObtainDocAnnotationsJob < Struct.new(:annotator, :project, :docid, :options)
	include StateManagement
	include ActionView::Helpers::NumberHelper

	def perform
		doc = Doc.find(docid)
		doc.set_ascii_body if options[:encoding].present? && options[:encoding] == 'ascii'
		max_text_size = annotator.async_protocol ? Annotator::MaxTextAsync : Annotator::MaxTextSync
		slices = doc.get_slices(max_text_size, options[:span])

		if @job
			@job.messages << Message.create({sourcedb:doc.sourcedb, sourceid:doc.sourceid, body: "The document was too big to be processed at once (#{number_with_delimiter(doc.body.length)} > #{number_with_delimiter(max_text_size)}). For proceding, it was divided into #{slices.length} slices."}) if slices.length > 1
			@job.update_attribute(:num_items, slices.length)
			@job.update_attribute(:num_dones, 0)
		end

		slices.each_with_index do |slice, i|
			timer_start = Time.now
			slice_text = doc.get_text(slice)
			text_length = slice_text.length

			annotations = annotator.obtain_annotations([{text:slice_text, sourcedb:doc.sourcedb, sourceid:doc.sourceid}]).first
			ttime = Time.now - timer_start

			timer_start = Time.now
			annotations = Annotation.normalize!(annotations)
			project.save_annotations(annotations, doc, options.merge(span:slice))
			stime = Time.now - timer_start

			annotations_num = annotations[:denotations].length
			if @job && options[:debug]
				@job.messages << Message.create({body: "Annotation obtained, sync (ttime:#{ttime}, stime:#{stime}, length:#{text_length}, num:#{annotations_num})"})
			end

		rescue RestClient::ExceptionWithResponse => e
			if e.response.nil?
				raise RuntimeError, e.message
			else
				if e.response.code == 201
					retrieve_and_store(e.response.headers[:location])
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
				@job.messages << Message.create({sourcedb:doc.sourcedb, sourceid:doc.sourceid, divid:doc.serial, body: e.message})
			else
				raise RuntimeError, e.message
			end
		ensure
			@job.update_attribute(:num_dones, i+1) if @job
		end
	end

	private

	def retrieve_and_store(url)
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
			doc = Doc.find_by_sourcedb_and_sourceid_and_serial(annotations[:sourcedb], annotations[:sourceid], annotations[:divid].present? ? annotations[:divid].to_i : 0)
			stime = Time.now - timer_start
			project.save_annotations(annotations, doc, options)
			if @job && options[:debug]
				ptime = status[:finished_at].to_time - status[:started_at].to_time
				qtime = status[:started_at].to_time - status[:submitted_at].to_time
				@job.messages << Message.create({body: "Annotation received, async (qtime:#{qtime}, ptime:#{ptime}, stime:#{stime}, length:#{text_length}, num:#{annotations_num})"})
			end
		when 'ERROR'
			raise RuntimeError, "The annotation server issued an error message: #{status[:error_message]}."
		else
			raise RuntimeError, "The annotation server reported an unknown status of the annotation task: #{status[:status]}."
		end

	rescue => e
		if @job
			@job.messages << Message.create({body: e.message})
		else
			raise ArgumentError, e.message
		end
	end
end
