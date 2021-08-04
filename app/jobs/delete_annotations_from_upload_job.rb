class DeleteAnnotationsFromUploadJob < ApplicationJob
	queue_as :low_priority

	def perform(project, filepath, options)
		dirpath = nil
		jsonfiles = if filepath.end_with?('.json')
			Dir.glob(filepath)
		else
			dirpath = File.join('tmp', File.basename(filepath, ".*"))
			unpack_cmd = "mkdir #{dirpath}; tar -xzf #{filepath} -C #{dirpath}"
			unpack_success_p = system(unpack_cmd)
			raise IOError, "Could not unpack the archive file." unless unpack_success_p
			Dir.glob(File.join(dirpath, '**', '*.json'))
		end

		docspecs = []
		jsonfiles.each_with_index do |jsonfile, i|
			json = File.read(jsonfile)
			begin
				o = JSON.parse(json, symbolize_names:true)
			rescue => e
				@job.messages << Message.create({body: "[#{File.basename(jsonfile)}] " + e.message})
				next
			end
			collection = o.is_a?(Array) ? o : [o]
			docspecs += collection.map{|o| {sourcedb:o[:sourcedb], sourceid:o[:sourceid]}}
		end
		docspecs.uniq!

		# check annotation files
		prepare_progress_record(docspecs.length)

		docspecs.each_with_index do |docspec, i|
			begin
				doc = Doc.find_by_sourcedb_and_sourceid(docspec[:sourcedb], docspec[:sourceid])
				project.delete_doc_annotations(doc) if doc.present?
			rescue => e
				@job.messages << Message.create({sourcedb: docspec[:sourcedb], sourceid: docspec[:sourceid], body: e.message})
			end
			@job.update_attribute(:num_dones, i + 1)
			check_suspend_flag
		end

		File.unlink(filepath)
		FileUtils.rm_rf(dirpath) unless dirpath.nil?
	end

	def job_name
		'Delete annotations from documents'
	end
end
