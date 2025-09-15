class UploadDocsJob < ApplicationJob
	include UseJobRecordConcern
	include UploadFilesConcern

	queue_as :low_priority

	def perform(project, filepath, options)
		dirpath = prepare_upload_files(filepath)

		all_txt_files  = "*.txt"
		all_json_files  = "*.json"
		all_applicable_files = "*.{json,txt}"

		file_count = Dir.glob(File.join(dirpath, '**', all_applicable_files)).count { |file| File.file?(file) }

		prepare_progress_record(file_count)

		username = project.user
		mode = options[:mode].to_sym
		num_dones = 0
		num_updated_or_skipped = 0

		Dir.glob(File.join(dirpath, '**', all_applicable_files)) do |filepath|
			# Check if it's a file and not a directory (glob should return only files, but just to be safe)
			if File.file?(filepath)
				begin
					ext = File.extname(filepath)
					hdoc = case ext
						when '.json'
							json_string = File.read(filepath)
							JSON.parse(json_string, symbolize_names:true).select{|k,v| [:sourcedb, :sourceid, :text, :source].include? k}
						when '.txt'
							sourcedb, sourceid = if options.has_key? :sourcedb
								[options[:sourcedb], options[:sourceid]]
							else
								Doc.parse_filename(File.basename(filepath, ext))
							end

							{
								text: File.read(filepath),
								sourcedb: sourcedb,
								sourceid: sourceid
							}
					end

					hdoc = Doc.hdoc_normalize!(hdoc, username, options[:root] == true)
					same_doc = Doc.find_by sourcedb: hdoc[:sourcedb], sourceid: hdoc[:sourceid]
					if same_doc.present?
						if mode == :update
							error_messages = same_doc.revise(hdoc)
							raise RuntimeError, error_messages.join("\n") if error_messages.present?
						end
						num_updated_or_skipped += 1
						project.has_doc?(same_doc) || project.add_doc!(same_doc)
					else
						doc = Doc.store_hdoc!(hdoc)
						project.add_doc!(doc)
					end
					num_dones += 1
				rescue => e
					raise e if @job.nil?
					@job.add_message body: "[#{fpath}] #{e.message}"
				ensure
					@job&.update_attribute(:num_dones, num_dones)
					check_suspend_flag
				end
			end
		end

		@job&.add_message body: "#{num_updated_or_skipped} docs were #{mode == :update ? 'updated' : 'skipped'}." if num_updated_or_skipped > 0
	ensure
		remove_upload_files(filepath, dirpath)
	end

	def job_name
		"Upload documents"
	end
end
