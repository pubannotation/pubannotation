require 'concurrent-ruby'

class ObtainAnnotationsJob < ApplicationJob
	include UseJobRecordConcern
	queue_as :low_priority

	THREAD_POOL_SIZE = 10
	BATCH_SIZE = 1000

	def perform(project, filepath, annotator, options)
		count = %x{wc -l #{filepath}}.split.first.to_i
		prepare_progress_record(count)

		pool = Concurrent::FixedThreadPool.new(THREAD_POOL_SIZE)
		failure_count = Concurrent::AtomicFixnum.new(0) # Thread-safe counter for failures

		@project = project
		@annotator = annotator
		@options = options.symbolize_keys

		File.open(filepath) do |file|
			id_batch = []

			file.each_line do |line|
				id_batch << line.strip.to_i
				if id_batch.size >= BATCH_SIZE
					process_batch(project, id_batch, pool, failure_count)
					id_batch.clear
				end
			end

			# Process any remaining IDs
			unless id_batch.empty?
				process_batch(project, id_batch, pool, failure_count)
			end
		end

		pool.shutdown
		pool.wait_for_termination

		@job&.decrement!(:num_dones, failure_count.value)
	end

	def job_name
		"Obtain annotations: #{resource_name}"
	end

private

	def process_batch(project, id_batch, pool, failure_count)
		begin
			ProjectDoc.where(project_id: project.id, doc_id: id_batch).find_each do |pdoc|
				pool.post do
					ActiveRecord::Base.connection_pool.with_connection do
						begin
							obtain_and_store_annotations(pdoc)
						rescue => e
							doc = pdoc.doc
							@job&.add_message(sourcedb:doc.sourcedb, sourceid:doc.sourceid, body:e.message)
							failure_count.increment
						end
					end
				end
			end
		rescue => e
			puts "Error processing batch: #{e.message}"
		ensure
			@job&.increment!(:num_dones, id_batch.size)
		end
	end

	def obtain_and_store_annotations(project_doc)
		annotations = @annotator.obtain_annotations_for_a_doc(project_doc.doc.hdoc)
		AnnotationUtils.normalize!(annotations)
		messages = project_doc.save_annotations(annotations, @options)
		messages.each {|message| @job&.add_message message}
	end

	# Helper method for exponential backoff
	def with_retries(max_retries, base_delay)
		attempts = 0
		begin
			yield
		rescue => e
			attempts += 1
			if attempts <= max_retries
				sleep(base_delay * (2**(attempts - 1))) # Exponential backoff
				retry
			else
				puts "Failed after #{attempts} attempts: #{e.message}"
			end
		end
	end
end