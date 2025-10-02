class StoreAnnotationsCollectionUploadJob < ApplicationJob
	include UseJobRecordConcern
	include UploadFilesConcern

	queue_as :low_priority

	MAX_BATCH_SIZE = 500
	MAX_CONCURRENT_JOBS = 20  # Match realistic Sidekiq worker availability

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

		# Wait for all batch jobs to complete
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
			increment_progress(1)
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

			# Throttle job creation - wait if too many jobs queued
			wait_for_queue_space

			ProcessAnnotationsBatchJob.perform_later(
				@project,
				@annotation_transaction,
				@options,
				@job_id
			)

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

		def wait_for_queue_space
			while general_queue_size >= StoreAnnotationsCollectionUploadJob::MAX_CONCURRENT_JOBS
				Rails.logger.info "[#{self.class.name}] Waiting for queue space (#{general_queue_size} jobs queued)..."
				sleep(0.2) # Reduced sleep time for faster job dispatching
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

		while true
			@job&.reload
			total_items = @job&.num_items || 0
			completed_items = @job&.num_dones || 0

			if completed_items >= total_items
				break
			end

			# Periodic project stats update for safety during long-running jobs (every 5 minutes)
			if Time.current - last_stats_update > 300 # 5 minutes
				Rails.logger.info "[#{self.class.name}] Performing periodic project stats update for safety"
				update_final_project_stats
				last_stats_update = Time.current
			end

			Rails.logger.info "[#{self.class.name}] Waiting for batch jobs: #{completed_items}/#{total_items} items processed"
			sleep(0.5) # Check every 0.5 seconds for faster responsiveness
		end

		# Update project counts after all batches complete to avoid lock contention
		update_final_project_stats
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

		# Use GROUP BY + JOIN approach for efficient bulk update
		sql = <<~SQL.squish
			UPDATE project_docs
			SET
				denotations_num = COALESCE(d.cnt, 0),
				blocks_num = COALESCE(b.cnt, 0),
				relations_num = COALESCE(r.cnt, 0)
			FROM
				project_docs pd_list
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM denotations WHERE project_id = #{@project.id} GROUP BY doc_id) d ON pd_list.doc_id = d.doc_id
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM blocks WHERE project_id = #{@project.id} GROUP BY doc_id) b ON pd_list.doc_id = b.doc_id
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM relations WHERE project_id = #{@project.id} GROUP BY doc_id) r ON pd_list.doc_id = r.doc_id
			WHERE project_docs.doc_id = pd_list.doc_id AND project_docs.project_id = pd_list.project_id AND project_docs.project_id = #{@project.id}
		SQL

		result = ActiveRecord::Base.connection.execute(sql)
		Rails.logger.info "[#{self.class.name}] Updated project_doc records for project #{@project.id}"
	end

	def update_doc_counts_bulk
		Rails.logger.info "[#{self.class.name}] Bulk updating doc counts..."

		# Use GROUP BY + JOIN approach for efficient bulk update
		sql = <<~SQL.squish
			UPDATE docs
			SET
				denotations_num = COALESCE(d.cnt, 0),
				blocks_num = COALESCE(b.cnt, 0),
				relations_num = COALESCE(r.cnt, 0),
				projects_num = COALESCE(p.cnt, 0)
			FROM
				(SELECT DISTINCT doc_id FROM project_docs WHERE project_id = #{@project.id}) pd
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM denotations GROUP BY doc_id) d ON pd.doc_id = d.doc_id
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM blocks GROUP BY doc_id) b ON pd.doc_id = b.doc_id
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM relations GROUP BY doc_id) r ON pd.doc_id = r.doc_id
				LEFT JOIN (SELECT doc_id, COUNT(*) as cnt FROM project_docs GROUP BY doc_id) p ON pd.doc_id = p.doc_id
			WHERE docs.id = pd.doc_id
		SQL

		result = ActiveRecord::Base.connection.execute(sql)
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
