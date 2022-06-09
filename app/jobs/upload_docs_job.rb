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

		if @job
			prepare_progress_record(infiles.length)
		end

		username = project.user
		mode = options[:mode].to_sym
		created = false
		num_updated_or_skipped = 0
		sourcedbs_added = Set[]
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
					raise "The filename is expected to be in the form 'sourcedb-sourceid.txt'." unless fparts.length == 2

					text = File.read(fpath)

					{
						text: text,
						sourcedb: fparts[0],
						sourceid: fparts[1]
					}
				end

				hdoc = Doc.hdoc_normalize!(hdoc, username, options[:root] == true)

				same_docs = Doc.where(sourcedb: hdoc[:sourcedb], sourceid: hdoc[:sourceid])
				same_doc = if same_docs.count == 1
					same_docs.first
				elsif same_docs.count > 1
					raise ArgumentError, "Multiple entries for #{hdoc[:sourcedb]}:#{hdoc[:sourceid]} found."
				else
					nil
				end

				if same_doc.present?
					if mode == :update
						error_messages = same_doc.revise(hdoc)
						if @job
							error_messages.each{|m| @job.messages << Message.create({sourcedb:same_doc.sourcedb, sourceid:same_doc.sourceid, body:m})}
						elsif error_messages.present?
							raise error_messages.join("\n")
						end
					end
					num_updated_or_skipped += 1
					unless same_doc.projects.include? project
						same_doc.projects << project
						sourcedbs_added << hdoc[:sourcedb]
					end
				else
					doc = Doc.new(hdoc)
					r = Doc.import [doc]
					raise RuntimeError, "documents import error" unless r.failed_instances.empty?
					created = true
					doc.projects << project
					sourcedbs_added << hdoc[:sourcedb]
				end
			rescue => e
				message = "[#{fpath}] #{e.message}"
				if @job
					@job.messages << Message.create({body: message})
				else
					raise ArgumentError, message
				end
			ensure
				if @job
					@job.update_attribute(:num_dones, i + 1)
					check_suspend_flag
				end
			end
		end

		if @job
			@job.messages << Message.create({body: "#{num_updated_or_skipped} docs were #{mode == :update ? 'updated' : 'skipped'}."}) if num_updated_or_skipped > 0
		end

		unless sourcedbs_added.empty?
			ActionController::Base.new.expire_fragment("sourcedb_counts") if created
			ActionController::Base.new.expire_fragment("sourcedb_counts_#{project.name}")
			ActionController::Base.new.expire_fragment("count_docs_#{project.name}")
			sourcedbs_added.each{|sdb| ActionController::Base.new.expire_fragment("count_#{sdb}_#{project.name}")}
		end

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
