class UploadDocsJob < ApplicationJob
	queue_as :low_priority

	def perform(project, dirpath, options, filename)
		upfilepath = Dir.glob(File.join(dirpath, '**', '*')).first

		infiles = if upfilepath.end_with?('.json') || upfilepath.end_with?('.txt')
			[upfilepath]
		else
			unpackpath = File.join(dirpath, File.basename(upfilepath, ".*"))
			unpack_cmd = "mkdir #{unpackpath}; tar -xzf #{upfilepath} -C #{unpackpath}"
			unpack_success_p = system(unpack_cmd)
			raise IOError, "Could not unpack the archive file." unless unpack_success_p
			Dir.glob(File.join(unpackpath, '**', '*.json')) + Dir.glob(File.join(unpackpath, '**', '*.txt'))
		end.sort

		prepare_progress_record(infiles.length)

		username = project.user
		mode = options[:mode].to_sym
		num_updated_or_skipped = 0
		infiles.each_with_index do |fpath, i|
			begin
				ext = File.extname(fpath)
				fname = File.basename(fpath, ext)

				hdoc = case ext
				when '.json'
					json = File.read(fpath)
					JSON.parse(json, symbolize_names:true).select{|k,v| [:sourcedb, :sourceid, :text, :source].include? k}
				when '.txt'
					fparts = fname.split('-')
					raise "The filename is expected to be in the form 'sourcedb-sourceid.txt'." unless fparts.length > 1
					sourceid = fparts.pop
					sourcedb = fparts.join('-')
					{
						text: File.read(fpath),
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
			rescue => e
				@job&.add_message body: "[#{fpath}] #{e.message}"
			ensure
				@job&.update_attribute(:num_dones, i + 1)
				check_suspend_flag
			end
		end

		@job&.add_message body: "#{num_updated_or_skipped} docs were #{mode == :update ? 'updated' : 'skipped'}." if num_updated_or_skipped > 0

		FileUtils.rm_rf(dirpath) unless dirpath.nil?
		true
	end

	def job_name
		"Upload documents: #{resource_name}"
	end

	private

	def resource_name
		self.arguments[3]
	end
end
