class StoreAnnotationsCollectionUploadJob < ApplicationJob
	include UseJobRecordConcern
	include UploadFilesConcern

	queue_as :low_priority

	MAX_BATCH_SIZE = 500
	MAX_CONCURRENT_JOBS = 20  # Match realistic Sidekiq worker availability
	CRASH_DETECTION_TIMEOUT = 10.minutes

	def perform(project, filepath, options)
		@project = project
		@options = options
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
	rescue Exceptions::JobSuspendError => e
		Rails.logger.warn "[#{self.class.name}] Job suspended - updating project stats to reflect partial progress"
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
			# Note: We don't increment here - parent tracks via tracking table
		end
	end

	class BatchState
		def initialize(project, options, job_id)
			@project = project
			@options = options
			@job_id = job_id
			@annotation_transaction = []
			@current_batch_size = 0
		end

		def add_to_batch(annotation)
			# Add to current batch
			@annotation_transaction << annotation
			@current_batch_size += count_annotations(annotation)

			if @current_batch_size >= StoreAnnotationsCollectionUploadJob::MAX_BATCH_SIZE
				flush_batch
			end
		end

		def flush_batch
			return unless @annotation_transaction.any?

			# Create tracking record FIRST (before enqueuing job)
			tracking = BatchJobTracking.create!(
				parent_job_id: @job_id,
				doc_identifiers: extract_doc_identifiers(@annotation_transaction),
				item_count: @current_batch_size,
				status: 'pending'
			)

			# Throttle job creation - wait if too many jobs queued
			wait_for_queue_space

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
				                  "child_job_id: #{child_job.job_id}, items: #{@current_batch_size})"
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
			# Count actual denotations and blocks from the parsed annotation
			denotation_count = annotation[:denotations]&.size || 0
			blocks_count = annotation[:blocks]&.size || 0
			total_count = denotation_count + blocks_count

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
			while general_queue_size >= StoreAnnotationsCollectionUploadJob::MAX_CONCURRENT_JOBS
				# Update progress while waiting for queue space
				update_progress_from_tracking

				Rails.logger.info "[#{self.class.name}] Waiting for queue space (#{general_queue_size} jobs queued)..."
				sleep(0.2) # Reduced sleep time for faster job dispatching
			end
		end

		def update_progress_from_tracking
			return unless @job_id

			stats = BatchJobTracking.stats_for_parent(@job_id)
			completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)
			total_items = stats.values.sum

			if total_items > 0
				Job.find(@job_id).update!(num_dones: completed_items, num_items: total_items)
			end
		end

		def general_queue_size
			Sidekiq::Queue.new('general').size
		end

		def reset_batch
			@annotation_transaction.clear
			@current_batch_size = 0
		end
	end

	def wait_for_batch_jobs_completion
		Rails.logger.info "[#{self.class.name}] Waiting for batch jobs to complete..."

		last_stats_update = Time.current
		last_crash_check = Time.current

		loop do
			@job&.reload

			# Get aggregated stats from tracking table (single efficient query)
			stats = BatchJobTracking.stats_for_parent(@job.id)

			# Calculate progress
			completed_items = (stats['completed'] || 0) + (stats['failed'] || 0) + (stats['crashed'] || 0)
			total_items = stats.values.sum

			# Update progress counter (parent controls it now, not children)
			@job.update!(num_dones: completed_items, num_items: total_items) if total_items > 0

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

			# Check completion
			break if completed_items >= total_items && total_items > 0

			# Log progress
			Rails.logger.info "[#{self.class.name}] Progress: #{completed_items}/#{total_items} items " \
			                  "(pending: #{stats['pending'] || 0}, running: #{stats['running'] || 0}, " \
			                  "completed: #{stats['completed'] || 0}, failed: #{stats['failed'] || 0}, " \
			                  "crashed: #{stats['crashed'] || 0})"

			# Handle failures
			if (stats['failed'] || 0) > 0 || (stats['crashed'] || 0) > 0
				log_failed_batches
			end

			sleep(0.5) # Check every 0.5 seconds for faster responsiveness
		end

		# Update project counts after all batches complete
		update_final_project_stats

		# Log summary
		log_completion_summary
	end

	def detect_and_mark_crashed_jobs
		crashed_count = BatchJobTracking
			.for_parent(@job.id)
			.possibly_crashed(CRASH_DETECTION_TIMEOUT)
			.count

		if crashed_count > 0
			Rails.logger.warn "[#{self.class.name}] Detected #{crashed_count} potentially crashed jobs"

			# Mark them as crashed
			BatchJobTracking
				.for_parent(@job.id)
				.possibly_crashed(CRASH_DETECTION_TIMEOUT)
				.find_each do |tracking|
					tracking.mark_crashed!
					log_crashed_batch(tracking)
				end
		end
	end

	def log_failed_batches
		# Log details about failed/crashed batches (but not too many to avoid spam)
		BatchJobTracking
			.for_parent(@job.id)
			.where(status: %w[failed crashed])
			.limit(10)
			.each do |tracking|
				@job&.add_message(
					sourcedb: 'batch_error',
					sourceid: "tracking_#{tracking.id}",
					body: "#{tracking.status.upcase}: #{tracking.doc_summary} - #{tracking.error_message}"
				)
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

	def log_completion_summary
		stats = BatchJobTracking.stats_for_parent(@job.id)

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

		# Process any deferred replacement operations first
		process_deferred_replacements

		begin
			# Calculate actual counts from database to ensure accuracy
			denotations_count = @project.denotations.count
			blocks_count = @project.blocks.count
			relations_count = @project.relations.count

			# Update project with final counts and timestamps using a single atomic operation
			@project.update!(
				denotations_num: denotations_count,
				blocks_num: blocks_count,
				relations_num: relations_count,
				annotations_updated_at: Time.current,
				updated_at: Time.current
			)

			# Update project_doc counts for all docs in this project using bulk operations
			update_project_doc_counts_bulk
			update_doc_counts_bulk

			Rails.logger.info "[#{self.class.name}] Project stats updated: #{denotations_count} denotations, #{blocks_count} blocks, #{relations_count} relations"
		rescue => e
			Rails.logger.error "[#{self.class.name}] Failed to update project stats: #{e.message}"
			# Don't re-raise - we want the job to complete even if stats update fails
		end
	end

	def update_project_doc_counts_bulk
		Rails.logger.info "[#{self.class.name}] Bulk updating project_doc counts..."
		ProjectDoc.bulk_update_counts(project_id: @project.id)
		Rails.logger.info "[#{self.class.name}] Updated project_doc records for project #{@project.id}"
	end

	def update_doc_counts_bulk
		Rails.logger.info "[#{self.class.name}] Bulk updating doc counts..."
		doc_ids = @project.project_docs.pluck(:doc_id).uniq
		Doc.bulk_update_docs_counts(doc_ids: doc_ids) if doc_ids.any?
		Rails.logger.info "[#{self.class.name}] Updated doc records for project #{@project.id}"
	end

	def process_deferred_replacements
		# Collect all docs needing replacement from job messages
		replacement_docs = Set.new

		@job&.messages&.each do |message|
			if message.sourceid.include?('replacement_cleanup') && message.body.start_with?('DOCS_NEEDING_REPLACEMENT:')
				doc_ids_str = message.body.sub('DOCS_NEEDING_REPLACEMENT:', '')
				doc_ids = doc_ids_str.split(',').map(&:to_i)
				replacement_docs.merge(doc_ids)
			end
		end

		return unless replacement_docs.any?

		Rails.logger.info "[#{self.class.name}] Processing deferred replacement cleanup for #{replacement_docs.size} documents..."

		# Perform batch cleanup operations for all docs needing replacement
		# Use smaller transactions to reduce lock time
		replacement_docs.each_slice(10) do |doc_batch|
			ActiveRecord::Base.transaction do
				Rails.logger.info "[#{self.class.name}] Cleaning up batch of #{doc_batch.size} documents for replacement mode"

				# Delete all existing annotations for these docs in batch
				Denotation.where(project_id: @project.id, doc_id: doc_batch).delete_all
				Block.where(project_id: @project.id, doc_id: doc_batch).delete_all
				Relation.where(project_id: @project.id, doc_id: doc_batch).delete_all
				Attrivute.where(project_id: @project.id, doc_id: doc_batch).delete_all
			end

			# Very small delay to prevent overwhelming the database
			sleep(0.01) if replacement_docs.size > 100
		end

		Rails.logger.info "[#{self.class.name}] Completed deferred replacement cleanup for #{replacement_docs.size} documents"
	end
end
