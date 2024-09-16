require 'concurrent-ruby'

class ObtainAnnotationsJob < ApplicationJob
	include UseJobRecordConcern
	queue_as :low_priority

	THREAD_POOL_SIZE = 5
	PROGRESS_UPDATE_INTERVAL = THREAD_POOL_SIZE * 2
	BATCH_SIZE = 1000

	def perform(project, filepath, annotator_name, options)
		@project = project
		@annotator = nil
		@options = options.symbolize_keys
		@pool = Concurrent::FixedThreadPool.new(THREAD_POOL_SIZE)
		@count_completed = Concurrent::AtomicFixnum.new(0) # Thread-safe counter for completed tasks
		@count_failure   = Concurrent::AtomicFixnum.new(0) # Thread-safe counter for failures

		count = %x{wc -l #{filepath}}.split.first.to_i
		ActiveRecord::Base.connection_pool.with_connection do
			prepare_progress_record(count)
			@annotator = Annotator.find_by_name(annotator_name)
		end

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

		@pool.shutdown
		@pool.wait_for_termination
		ActiveRecord::Base.connection_pool.with_connection do
			@job&.update_attribute(:num_dones, @count_completed.value)
		end
	end

	def job_name
		"Obtain annotations: #{resource_name}"
	end

private

	def process_batch(project, id_batch)
		begin
			pdocs_with_docs = ActiveRecord::Base.connection_pool.with_connection do
				pdocs = ProjectDoc.where(project_id: project.id, doc_id: id_batch)
				pdocs.includes(:doc)
			end

			pdocs_with_docs.each do |pdoc|
				@pool.post do
					begin
						obtain_and_store_annotations(pdoc)
						@count_completed.increment
						if @count_completed.value % PROGRESS_UPDATE_INTERVAL == 0
							ActiveRecord::Base.connection_pool.with_connection do
								@job&.update_attribute(:num_dones, @count_completed.value)
							end
						end
					rescue => e
						if @job
							doc = pdoc.doc
							ActiveRecord::Base.connection_pool.with_connection do
								@job.add_message(sourcedb:doc.sourcedb, sourceid:doc.sourceid, body:e.message)
							end
							@count_failure.increment
						else
							puts e.message
							puts e.backtrace.join("\n")
							puts "Error in a thread <-----"
						end
					end
				end
			end
		rescue => e
			if @job
				ActiveRecord::Base.connection_pool.with_connection do
					@job.add_message(body:e.message)
				end
			else
				puts "Error processing batch: #{e.message}"
			end
		end
	end

	def obtain_and_store_annotations(project_doc)
		# project_doc includes doc, thus connection is not necessary to access the doc.
		annotations = @annotator.obtain_annotations_for_a_doc(project_doc.doc.hdoc)

		ActiveRecord::Base.connection_pool.with_connection do
			messages = project_doc.save_annotations(annotations, @options)
			messages.each {|message| @job&.add_message message}
		end
	end

	def resource_name
		self.arguments[2]
	end
end