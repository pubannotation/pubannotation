class StoreAnnotationsCollectionUploadJob < ApplicationJob
	include UseJobRecordConcern
	include UploadFilesConcern

	queue_as :low_priority

	MAX_BATCH_SIZE = 500
	MAX_QUEUE_SIZE = 100  # Maximum jobs allowed in Sidekiq queue before throttling
	CRASH_DETECTION_TIMEOUT = 10.minutes

	def perform(project, filepath, options)
		@project = project
		@options = options
		@invalid_items_count = 0  # Track invalid items that failed validation
		dirpath = prepare_upload_files(filepath)

		all_json_files  = "*.json"
		all_jsonl_files = "*.jsonl"
		all_applicable_files = "*.{json,jsonl}"

		# Count total items for progress tracking
		total_items = count_total_items(dirpath, all_applicable_files)
		prepare_progress_record(total_items)

		# Process all files with child jobs
		process_files(dirpath, all_json_files)
		process_files(dirpath, all_jsonl_files)

		# Wait for all batch jobs to complete (parent now monitors children)
		wait_for_batch_jobs_completion

		# Update project-level counters from database (for both immediate and async execution)
		update_final_project_stats
	rescue Exceptions::JobSuspendError => e
		Rails.logger.warn "[#{self.class.name}] Job suspended - updating progress counter and project stats"

		# Update progress counter to show how far we got
		update_progress_from_tracking

		# Update project stats to match current database state, even though job is incomplete
		update_final_project_stats
		raise e  # Re-raise to maintain suspension behavior
	ensure
		remove_upload_files(filepath, dirpath)
	end

	def job_name
		'Upload annotations'
	end

	private

	def update_progress_from_tracking
		return unless @job

		stats = BatchJobTracking.uncached do
			BatchJobTracking.stats_for_parent(@job.id)
		end
		completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)

		# Add invalid items that failed validation
		completed_with_invalid = completed_items + (@invalid_items_count || 0)

		# Only update num_dones, not num_items (which was set at the start)
		@job.update!(num_dones: completed_with_invalid) if completed_with_invalid > 0
	end

	def process_files(dirpath, pattern)
		files_found = Dir.glob(File.join(dirpath, '**', pattern))

		files_found.each do |filepath|
			next unless File.file?(filepath)

			# Create a new batch state for this file
			Rails.logger.info "[#{self.class.name}] Creating BatchState with job_id: #{@job&.id.inspect}"
			file_batch_state = BatchState.new(@project, @options, @job&.id)

			if filepath.end_with?('.jsonl')
				process_jsonl_file(filepath, file_batch_state)
			else
				process_json_file(filepath, file_batch_state)
			end

			# Check for suspension
			check_suspend_flag

			# Flush any remaining batch for this file
			file_batch_state.flush_batch
		end
	end

	def process_jsonl_file(filepath, batch_state)
		filename = File.basename(filepath)
		File.open(filepath, 'r') do |file|
			file.each_line.with_index(1) do |line, line_num|
				process_json_content(line.chomp, "#{filename}:#{line_num}", batch_state)

				# Periodic check for suspension
				check_suspend_flag if line_num % 100 == 0
			end
		end

	end

	def process_json_file(filepath, batch_state)
		filename = File.basename(filepath)
		json_content = File.read(filepath)
		process_json_content(json_content, filename, batch_state)
	end

	def process_json_content(json_content, source, batch_state)
		annotation = begin
			parse_and_validate_json(json_content)
		rescue ArgumentError => e
			@job&.add_message(
				sourcedb: '*',
				sourceid: source,
				body: "JSON validation error: #{e.message}"
			)
			nil
		end

		if annotation
			batch_state.add_to_batch(annotation)
		else
			# Even invalid annotations count toward progress
			# (they won't be reprocessed, so we need to count them)
			# Invalid items don't go to batches, so track separately
			@invalid_items_count += 1
		end
	end

	class BatchState
		def initialize(project, options, job_id)
			@project = project
			@options = options
			@job_id = job_id
			@annotation_transaction = []
			@current_batch_size = 0
			@last_doc_identifier = nil  # Track last document to detect consecutive duplicates
		end

		def add_to_batch(annotation)
			# Check for consecutive duplicate documents in replace mode
			current_doc_identifier = "#{annotation[:sourcedb]}:#{annotation[:sourceid]}"
			if @options[:mode] == 'replace' && @last_doc_identifier == current_doc_identifier
				# Add user-friendly message
				Job.find(@job_id).add_message(
					sourcedb: annotation[:sourcedb],
					sourceid: annotation[:sourceid],
					body: "This document appears multiple times in your upload file. " \
					      "In replace mode, each document should appear only once. " \
					      "Please use 'add' mode instead, or remove duplicate documents from your file."
				)
				# Terminate the job
				raise ArgumentError, "Duplicate document detected in replace mode: #{current_doc_identifier}"
			end

			# Flush batch if we've exceeded threshold AND this is a new document
			# This ensures all annotations for the same document go to the same batch
			if @current_batch_size >= StoreAnnotationsCollectionUploadJob::MAX_BATCH_SIZE &&
			   current_doc_identifier != @last_doc_identifier
				flush_batch
			end

			# Add to current batch
			@annotation_transaction << annotation
			@current_batch_size += count_annotations(annotation)
			@last_doc_identifier = current_doc_identifier
		end

		def flush_batch
			return unless @annotation_transaction.any?

			# If no parent job (immediate execution), process directly without batch tracking
			if @job_id.nil?
				ProcessAnnotationsBatchJob.perform_now(
					@project,
					@annotation_transaction,
					@options,
					nil,  # No parent job
					nil   # No tracking
				)
				reset_batch
				return
			end

			# Throttle job creation - wait if queue is full
			wait_for_queue_space

			# Create tracking record FIRST (before enqueuing job)
			tracking = BatchJobTracking.create!(
				parent_job_id: @job_id,
				doc_identifiers: extract_doc_identifiers(@annotation_transaction),
				annotation_objects_count: @annotation_transaction.size,  # For progress tracking
				item_count: @current_batch_size,  # Total annotation items
				status: 'pending'
			)

			begin
				# Enqueue child job with tracking ID
				child_job = ProcessAnnotationsBatchJob.perform_later(
					@project,
					@annotation_transaction,
					@options,
					@job_id,
					tracking.id  # Pass tracking ID to child
				)

				# Update tracking record with Sidekiq job ID
				tracking.update!(child_job_id: child_job.job_id)

				Rails.logger.info "[#{self.class.name}] Enqueued batch (tracking_id: #{tracking.id}, " \
				                  "child_job_id: #{child_job.job_id}, annotations: #{@annotation_transaction.size})"
			rescue => e
				# If enqueue fails, mark tracking as failed immediately
				tracking.mark_failed!(e)
				Rails.logger.error "[#{self.class.name}] Failed to enqueue batch: #{e.message}"
				raise
			end

			reset_batch
		end

		private

		def count_annotations(annotation)
			# Count all annotation items (denotations, blocks, relations, attributes)
			# This is used for memory estimation
			denotation_count = annotation[:denotations]&.size || 0
			blocks_count = annotation[:blocks]&.size || 0
			relations_count = annotation[:relations]&.size || 0
			attributes_count = annotation[:attributes]&.size || 0
			total_count = denotation_count + blocks_count + relations_count + attributes_count

			# Return at least 1 to avoid zero-size batches
			[total_count, 1].max
		end

		def extract_doc_identifiers(annotations)
			annotations.map do |a|
				{
					sourcedb: a[:sourcedb],
					sourceid: a[:sourceid]
				}
			end
		end

		def wait_for_queue_space
			max_wait_iterations = 150  # 5 minutes max (150 * 2s)
			iterations = 0

			loop do
				# Check Sidekiq queue size directly
				queue = Sidekiq::Queue.new('general')
				current_queue_size = queue.size

				# If queue is full, wait for workers to process jobs
				if current_queue_size >= StoreAnnotationsCollectionUploadJob::MAX_QUEUE_SIZE
					iterations += 1

					# Prevent infinite loop - abort if queue stays full too long
					if iterations >= max_wait_iterations
						error_msg = "Sidekiq queue has been full for #{max_wait_iterations * 2} seconds " \
						            "(#{max_wait_iterations} iterations). Aborting to prevent system overload. " \
						            "Current queue size: #{current_queue_size}"
						Rails.logger.error "[#{self.class.name}] #{error_msg}"
						raise error_msg
					end

					# Update progress while waiting
					update_progress_from_tracking

					Rails.logger.info "[#{self.class.name}] Waiting for queue space " \
					                  "(iteration #{iterations}/#{max_wait_iterations}, " \
					                  "queue size: #{current_queue_size}, " \
					                  "max: #{StoreAnnotationsCollectionUploadJob::MAX_QUEUE_SIZE})..."
					sleep(0.5)
					next
				end

				# Queue has space
				break
			end
		end

		def update_progress_from_tracking
			return unless @job_id

			stats = BatchJobTracking.uncached do
				BatchJobTracking.stats_for_parent(@job_id)
			end
			completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)

			# Skip update if value hasn't changed (reduces lock contention)
			return if @last_progress_update == completed_items
			@last_progress_update = completed_items

			# Use direct SQL UPDATE to avoid SELECT+UPDATE roundtrip and reduce lock time
			# Only update num_dones, not num_items (which was set at the start)
			if completed_items > 0
				Job.where(id: @job_id).update_all(
					num_dones: completed_items,
					updated_at: Time.current
				)
			end
		end

		def reset_batch
			@annotation_transaction.clear
			@current_batch_size = 0
		end
	end

	def wait_for_batch_jobs_completion
		# If no parent job (immediate execution), batches were processed synchronously - nothing to wait for
		return unless @job

		Rails.logger.info "[#{self.class.name}] Waiting for batch jobs to complete..."

		last_stats_update = Time.current
		last_crash_check = Time.current
		start_time = Time.current
		max_wait_time = 2.hours  # Absolute maximum wait time

		loop do
			@job&.reload

			# Prevent infinite loop - abort if waiting too long
			elapsed_time = Time.current - start_time
			if elapsed_time > max_wait_time
				error_msg = "Batch jobs have not completed after #{max_wait_time.inspect}. " \
				            "Aborting to prevent infinite wait."
				Rails.logger.error "[#{self.class.name}] #{error_msg}"
				raise error_msg
			end

			# Get aggregated stats from tracking table (single efficient query)
			# Force fresh query - bypass ActiveRecord query cache to see updates from child jobs
			stats = BatchJobTracking.uncached do
				BatchJobTracking.stats_for_parent(@job.id)
			end

			# Calculate progress
			completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)
			total_items = stats.values.sum

			# Add invalid items that failed validation (they don't go to batches)
			completed_with_invalid = completed_items + @invalid_items_count

			# Update progress count AND touch updated_at as heartbeat (reduces lock contention with direct SQL)
			# (num_items was already set correctly at the start)
			if completed_with_invalid > 0
				Job.where(id: @job.id).update_all(
					num_dones: completed_with_invalid,
					updated_at: Time.current
				)
				@job.reload  # Reload to get updated values for next iteration
			end

			# Detect crashed jobs every 2 minutes
			if Time.current - last_crash_check > 120
				detect_and_mark_crashed_jobs
				last_crash_check = Time.current
			end

			# Periodic project stats update for safety during long-running jobs (every 5 minutes)
			if Time.current - last_stats_update > 300 # 5 minutes
				Rails.logger.info "[#{self.class.name}] Performing periodic project stats update for safety"
				update_final_project_stats
				last_stats_update = Time.current
			end

			# Check completion (total from batches + invalid items)
			break if completed_items >= total_items && total_items > 0

			# Log progress (include invalid items in count)
			Rails.logger.info "[#{self.class.name}] Progress: #{completed_with_invalid}/#{total_items + @invalid_items_count} items " \
			                  "(pending: #{stats['pending'] || 0}, running: #{stats['running'] || 0}, " \
			                  "completed: #{stats['completed'] || 0}, failed: #{stats['failed'] || 0}, " \
			                  "crashed: #{stats['crashed'] || 0}, invalid: #{@invalid_items_count})"

			sleep(2) # Check every 2 seconds to reduce system load
		end

		# Do final progress update before cleanup (in case any jobs were marked crashed/failed after loop)
		stats = BatchJobTracking.uncached do
			BatchJobTracking.stats_for_parent(@job.id)
		end
		final_completed = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)
		# Add invalid items to final count
		final_with_invalid = final_completed + @invalid_items_count
		if final_with_invalid > 0
			Job.where(id: @job.id).update_all(num_dones: final_with_invalid, updated_at: Time.current)
			@job.reload
		end

		# Log summary
		log_completion_summary
	end

	def detect_and_mark_crashed_jobs
		# Detect jobs that started running but stopped updating (crashed workers)
		crashed_running = BatchJobTracking
			.for_parent(@job.id)
			.possibly_crashed(CRASH_DETECTION_TIMEOUT)
			.count

		if crashed_running > 0
			Rails.logger.warn "[#{self.class.name}] Detected #{crashed_running} crashed running jobs"

			BatchJobTracking
				.for_parent(@job.id)
				.possibly_crashed(CRASH_DETECTION_TIMEOUT)
				.find_each do |tracking|
					tracking.mark_crashed!
					log_crashed_batch(tracking)
				end
		end

		# Detect jobs stuck in pending that never started (lost child jobs)
		stale_pending = BatchJobTracking
			.for_parent(@job.id)
			.stale_pending(5.minutes)
			.count

		if stale_pending > 0
			Rails.logger.warn "[#{self.class.name}] Detected #{stale_pending} stale pending jobs (child jobs never started)"

			BatchJobTracking
				.for_parent(@job.id)
				.stale_pending(5.minutes)
				.find_each do |tracking|
					tracking.update!(
						status: 'failed',
						error_message: 'Child job never started - likely lost by Sidekiq or worker crashed before execution',
						completed_at: Time.current
					)
					log_stale_pending_batch(tracking)
				end
		end
	end

	def log_crashed_batch(tracking)
		@job&.add_message(
			sourcedb: 'batch_crashed',
			sourceid: "tracking_#{tracking.id}",
			body: "CRASHED: Batch with #{tracking.item_count} items (#{tracking.doc_summary}) " \
			      "did not complete within #{CRASH_DETECTION_TIMEOUT.inspect}"
		)
	end

	def log_stale_pending_batch(tracking)
		@job&.add_message(
			sourcedb: 'batch_stale',
			sourceid: "tracking_#{tracking.id}",
			body: "STALE PENDING: Batch with #{tracking.item_count} items (#{tracking.doc_summary}) " \
			      "never started execution - child job was lost or never picked up by Sidekiq"
		)
	end

	def log_completion_summary
		stats = BatchJobTracking.uncached do
			BatchJobTracking.stats_for_parent(@job.id)
		end

		Rails.logger.info "[#{self.class.name}] Batch processing completed: " \
		                  "completed: #{stats['completed'] || 0}, " \
		                  "failed: #{stats['failed'] || 0}, " \
		                  "crashed: #{stats['crashed'] || 0}"

		# Cleanup tracking records after successful completion
		cleanup_tracking_records
	end

	def cleanup_tracking_records
		# Delete tracking records for this job (they're no longer needed)
		# Note: If you want to keep them for historical analysis, comment this out
		deleted_count = BatchJobTracking.for_parent(@job.id).delete_all
		Rails.logger.info "[#{self.class.name}] Cleaned up #{deleted_count} tracking records"
	end

	def count_total_items(dirpath, pattern)
		total = 0
		Dir.glob(File.join(dirpath, '**', pattern)) do |filepath|
			if File.file?(filepath)
				if filepath.end_with?('.jsonl')
					File.open(filepath, "r") { |file| total += file.each_line.count }
				else
					total += 1
				end
			end
		end
		total
	end

	def parse_and_validate_json(json_string)
		# Parse JSON
		parsed_json = begin
			JSON.parse(json_string, symbolize_names: true)
		rescue JSON::ParserError => e
			raise ArgumentError, "Invalid JSON format"
		end

		raise ArgumentError, "JSON array format not supported" if parsed_json.is_a?(Array)
		annotation = parsed_json

		# Validate required fields
		unless annotation[:sourcedb].present? && annotation[:sourceid].present?
			raise ArgumentError, "sourcedb and sourceid are required"
		end

		# Normalize annotation
		AnnotationUtils.normalize!(annotation)

		annotation
	end

	private

	def update_final_project_stats
		Rails.logger.info "[#{self.class.name}] Updating final project statistics..."

		begin
			@project.update_annotation_stats_from_database
			Rails.logger.info "[#{self.class.name}] Project stats updated: #{@project.denotations_num} denotations, #{@project.blocks_num} blocks, #{@project.relations_num} relations"
		rescue => e
			Rails.logger.error "[#{self.class.name}] Failed to update project stats: #{e.message}"
			# Don't re-raise - we want the job to complete even if stats update fails
		end
	end

end
