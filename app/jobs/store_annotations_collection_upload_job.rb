class StoreAnnotationsCollectionUploadJob < ApplicationJob
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
				begin
					validated_annotations = ValidatedAnnotations.new(json_string)
					batch_item << validated_annotations
					if batch_item.enough?
						begin
							threads << execute_batch(project, options, batch_item)
						ensure
							batch_item = BatchItem.new
						end
					end
				rescue => e
					process_exception("[#{File.basename(filepath)}] #{e.message}")
				end

				@job&.increment!(:num_dones)
				check_suspend_flag
			end
		end

		# Process the remaining batch items.
		unless batch_item.empty?
			begin
				threads << execute_batch(project, options, batch_item)
			rescue => e
				process_exception("[#{File.basename(filepath)}] #{e.message}")
			end
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
						begin
							validated_annotations = ValidatedAnnotations.new(json_string)
							batch_item << validated_annotations
							if batch_item.enough?
								begin
									threads << execute_batch(project, options, batch_item)
								ensure
									batch_item = BatchItem.new
								end
							end
						rescue => e
							process_exception("[#{File.basename(filepath)}] #{e.message}")
						end

						@job&.increment!(:num_dones)
						check_suspend_flag
					end
				end

				# Process the remaining batch items.
				unless batch_item.empty?
					begin
						threads << execute_batch(project, options, batch_item)
					rescue => e
						process_exception("[#{File.basename(filepath)}] #{e.message}")
					end
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
		StoreAnnotationsCollection.new(project, batch_item.annotation_transaction, options, @job).call
	end

	def store_docs(project, ids_list)
		ids_list.each do |ids|
			num_added, num_sequenced, messages = project.add_docs(ids)
			messages.each do |message|
				@job&.add_message(message.class == Hash ? message : { body: message[0..250] })
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
		@job.increment!(:num_items, by)
	end

	def process_exception(message)
		@job.add_message body: message
	end
end
