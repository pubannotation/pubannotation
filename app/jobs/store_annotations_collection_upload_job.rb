class StoreAnnotationsCollectionUploadJob < ApplicationJob
	include UseJobRecordConcern
	include UploadFilesConcern

	queue_as :low_priority

	def perform(project, filepath, options)
		dirpath = prepare_upload_files(filepath)

		all_json_files  = "*.json"
		all_jsonl_files = "*.jsonl"
		all_applicable_files = "*.{json,jsonl}"

		file_count = Dir.glob(File.join(dirpath, '**', all_applicable_files)).count { |file| File.file?(file) }

		# initialize the counter
		prepare_progress_record(file_count)

		# initialize necessary variables
		batch_item = BatchItem.new
		threads = []

		# Process json files
		Dir.glob(File.join(dirpath, '**', all_json_files)) do |filepath|
			# Check if it's a file and not a directory (glob should return only files, but just to be safe)
			if File.file?(filepath)
				json_string = File.read(filepath)
				validated_annotations = ValidatedAnnotations.new(json_string)
				batch_item << validated_annotations
				if batch_item.enough?
					begin
						threads << execute_batch(project, options, batch_item)
					ensure
						batch_item = BatchItem.new
					end
				end

				@job&.increment!(:num_dones)
				check_suspend_flag
			end
		end

		# Process the remaining batch items.
		unless batch_item.empty?
			threads << execute_batch(project, options, batch_item)
			batch_item = BatchItem.new
		end

		# Process jsonl files
		Dir.glob(File.join(dirpath, '**', all_jsonl_files)) do |filepath|
			# Check if it's a file and not a directory (glob should return only files, but just to be safe)
			if File.file?(filepath)
				line_count = count_lines(filepath)
				scheduled_num_increment!(line_count - 1)

				File.open(filepath, "r") do |file|
					file.each_line.with_index do |json_string, i|
						validated_annotations = ValidatedAnnotations.new(json_string)
						batch_item << validated_annotations
						if batch_item.enough?
							begin
								threads << execute_batch(project, options, batch_item)
							ensure
								batch_item = BatchItem.new
							end
						end

						@job&.increment!(:num_dones)
						check_suspend_flag
					end
				end

				# Process the remaining batch items.
				unless batch_item.empty?
					threads << execute_batch(project, options, batch_item)
					batch_item = BatchItem.new
				end
			end
		end

		# Process the remaining batch items.
		threads.each(&:join)
	ensure
		remove_upload_files(filepath, dirpath)
	end

	def job_name
		'Upload annotations'
	end

	private

	def execute_batch(project, options, batch_item)
		store_docs(project, batch_item.source_ids_list)
		result = TextAlign::Aligner.new(
			project,
			batch_item.annotation_transaction,
			options,
			@job
		).call

		Thread.new do
			# We are creating our own threads that Rails do not manage.
			# Explicitly releases the connection to the DB.
			ActiveRecord::Base.connection_pool.with_connection do
				messages = result.save(project, options)
				messages.each { @job.add_message it }
			end
		end
	end

	def store_docs(project, ids_list)
		ids_list.each do |ids|
			num_added, num_sequenced, messages = project.add_docs(ids)
			messages.each do |message|
				@job&.add_message(message)
			end
		end
	end

	def count_lines(filepath)
		line_count = 0
		File.open(filepath, "r") do |file|
			file.each_line { line_count += 1 }
		end
		line_count
	end

	def scheduled_num_increment!(by = 1)
		@job&.increment!(:num_items, by)
	end
end
