require 'concurrent-ruby'

class ObtainAnnotationsJob < ApplicationJob
	include UseJobRecordConcern
	queue_as :low_priority

	THREAD_POOL_SIZE = 3
	PROGRESS_UPDATE_INTERVAL = THREAD_POOL_SIZE * 2
	BATCH_SIZE = 100

	def perform(project, filepath, annotator_name, options)
		@project = project
		@annotator = nil
		@options = options.symbolize_keys
		@pool = Concurrent::FixedThreadPool.new(THREAD_POOL_SIZE)
		@count_completed = Concurrent::AtomicFixnum.new(0) # Thread-safe counter for completed tasks
		@count_failure   = Concurrent::AtomicFixnum.new(0) # Thread-safe counter for failures
		@stop_checker = Concurrent::AtomicBoolean.new(false) # Flag to stop background checker

		checker_thread = start_suspension_checker

		count = File.foreach(filepath).count
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

		stop_suspension_checker(checker_thread)

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
		ensure
			# Log batch completion for debugging if needed
			# Actual cleanup happens during pool shutdown
		end
	end

	def obtain_and_store_annotations(project_doc)
		# project_doc includes doc, thus connection is not necessary to access the doc.
		annotations = @annotator.obtain_annotations_for_a_doc(project_doc.doc.hdoc)

		messages = project_doc.save_annotations(annotations, @options)
		unless messages.empty?
			ActiveRecord::Base.connection_pool.with_connection do
				messages.each {|message| @job&.add_message message}
			end
		end
	end

	def resource_name
		self.arguments[2]
	end

	def start_suspension_checker
		Thread.new do
			while !@stop_checker.true?
				begin
					ActiveRecord::Base.connection_pool.with_connection do
						if @job&.reload&.suspended?
							@pool.kill # Immediately kill pool to stop all queued work
							@job&.add_message(body: "Job suspended")
							break # Exit checker loop since job is suspended
						end
					end
				rescue => e
					# Ignore errors in background checker to avoid disrupting main job
				end
				sleep(2) # Check every 2 seconds
			end
		end
	end

	def stop_suspension_checker(checker_thread)
		# Stop background checker AFTER all threads are done
		@stop_checker.make_true
		checker_thread.join(5) # Wait up to 5 seconds for checker to stop

		# Ensure we don't access @job after checker thread might still be using it
		if checker_thread.alive?
			checker_thread.kill # Force kill if it didn't stop gracefully
		end
	end
end
