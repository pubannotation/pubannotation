class CreateAnnotationsRdfCollectionJob < ApplicationJob
	include UseJobRecordConcern

	queue_as :low_priority

	def perform(collection, options)
		if @job
			prepare_progress_record(collection.active_projects.count + 2)
		end

		# clear
		FileUtils.rm_f collection.rdf_zippath
		FileUtils.rm_f Dir.glob("#{collection.rdf_dirpath}/*") if forced?(options) && File.exist?(collection.rdf_dirpath)

		# prepare
		FileUtils.rm_f Dir.glob("#{collection.rdf_new_dirpath}/*")
		FileUtils.mkdir_p collection.rdf_new_dirpath

		docids_in_primary = collection.primary_docids

		collection.active_projects.each do |project|
			if project.rdf_needs_to_be_updated?(collection.rdf_dirpath)
				docids_specified = if CollectionProject.is_primary?(collection, project)
					nil
				else
					docids_in_primary
				end

				if @job
					active_job = CreateAnnotationsRdfJob.perform_later(project, docids_specified, collection.rdf_new_dirpath)
					monitor_job = Job.find_by(active_job_id: active_job.job_id)
					until monitor_job.finished_live?
						sleep(1)
						ActiveRecord::Base.connection.clear_query_cache
					end
				else
					puts "start creation, #{project.name} <====="
					CreateAnnotationsRdfJob.perform_now(project, docids_specified, collection.rdf_new_dirpath)
				end
			else
				FileUtils.cp collection.rdf_dirpath + '/' + project.annotations_rdf_filename, collection.rdf_new_dirpath
			end

			if @job
				@job.increment!(:num_dones, 1)
				check_suspend_flag
			end
		rescue => e
			if e.class == Exceptions::JobSuspendError
				raise e
			elsif @job
				@job.add_message body: e.message
			else
				raise e
			end
		end

		# creation of spans RDF
		if @job
			active_job = CreateSpansRdfCollectionJob.perform_later(collection)
			monitor_job = Job.find_by(active_job_id: active_job.job_id)
			until monitor_job.finished_live?
				sleep(1)
				ActiveRecord::Base.connection.clear_query_cache
			end
		else
			puts "start creation of span RDF <====="
			CreateSpansRdfCollectionJob.perform_now(collection)
		end

		@job.increment!(:num_dones, 1) if @job

		## rename the new RDF dir
		FileUtils.rm_rf collection.rdf_dirpath if File.exist? collection.rdf_dirpath
		FileUtils.mv collection.rdf_new_dirpath, collection.rdf_dirpath

		puts "start creation of collection RDF zip <====="
		collection.create_RDF_zip
		@job.increment!(:num_dones, 1) if @job
	end

	def forced?(options)
		options && options.has_key?(:forced) ? options[:forced] == true : false
	end

	def job_name
		"Create Annotation RDF Collection - #{resource_name}"
	end
end
