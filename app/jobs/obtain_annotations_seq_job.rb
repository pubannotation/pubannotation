class ObtainAnnotationsSeqJob < ApplicationJob
	include UseJobRecordConcern
	include SuspensionCheckConcern
	queue_as :low_priority

	PROGRESS_UPDATE_INTERVAL = 10
	BATCH_SIZE = 100

	def perform(project, filepath, annotator_name, options)
		@project = project
		@annotator = nil
		@options = options.symbolize_keys
		@count_completed = 0
		@count_failure = 0

		count = File.foreach(filepath).count
		prepare_progress_record(count)
		@annotator = Annotator.find_by_name(annotator_name)

		File.open(filepath) do |file|
			id_batch = []

			file.each_line do |line|
				id_batch << line.strip.to_i
				if id_batch.size >= BATCH_SIZE
					process_batch(project, id_batch)
					id_batch.clear
				end
			end

			# Process any remaining IDs
			unless id_batch.empty?
				process_batch(project, id_batch)
			end
		end

		@job&.update_attribute(:num_dones, @count_completed)
	end

	def job_name
		"Obtain annotations: #{resource_name}"
	end

private

	def process_batch(project, id_batch)
		begin
			pdocs = ProjectDoc.where(project_id: project.id, doc_id: id_batch)
			pdocs_with_docs = pdocs.includes(:doc)

			pdocs_with_docs.each do |pdoc|
				begin
					obtain_and_store_annotations(pdoc)
					@count_completed += 1
					if @count_completed % PROGRESS_UPDATE_INTERVAL == 0
						@job&.update_attribute(:num_dones, @count_completed)
					end
					check_suspend_flag
				rescue => e
					if @job
						doc = pdoc.doc
						@job.add_message(sourcedb:doc.sourcedb, sourceid:doc.sourceid, body:e.message)
						@count_failure += 1
					else
						puts e.message
						puts e.backtrace.join("\n")
						puts "Error processing document <-----"
					end
				end
			end
		rescue => e
			if @job
				@job.add_message(body:e.message)
			else
				puts "Error processing batch: #{e.message}"
			end
		end
	end

	def obtain_and_store_annotations(project_doc)
		# project_doc includes doc, thus connection is not necessary to access the doc.
		annotations = @annotator.obtain_annotations_for_a_doc(project_doc.doc.hdoc)

		messages = project_doc.save_annotations(annotations, @options)
		unless messages.empty?
			messages.each {|message| @job&.add_message message}
		end
	end

	def resource_name
		self.arguments[2]
	end

end
