class CreateAnnotationsRdfCollectionJob < ApplicationJob
	queue_as :low_priority

	def perform(collection, options)
		if @job
			prepare_progress_record(collection.primary_projects.count + 1)
		end

		FileUtils.mkdir_p collection.annotations_rdf_dirpath unless File.exists? collection.annotations_rdf_dirpath
		FileUtils.rm_f Dir.glob("#{collection.annotations_rdf_dirpath}/*")

		# creation of annotations RDF
		collection.primary_projects.each do |project|
			if forced?(options) || project.rdf_needs_to_be_updated?
				if @job
					active_job = CreateAnnotationsRdfJob.perform_later(project)
					monitor_job = active_job.create_job_record(collection.jobs, "Create Annotation RDF - #{project.name}")
					until monitor_job.finished_live?
						sleep(1)
						ActiveRecord::Base.connection.clear_query_cache
					end
				else
					puts "start creation, #{project.name} <====="
					CreateAnnotationsRdfJob.perform_now(project)
				end
			end
			FileUtils.ln_sf(project.annotations_trig_filepath, collection.annotations_rdf_dirpath)
			if @job
				@job.increment!(:num_dones, 1)
				check_suspend_flag
			end
		rescue => e
			if e.class == Exceptions::JobSuspendError
				raise e
			elsif @job
				@job.messages << Message.create({body: e.message})
			else
				raise e
			end
		end

		# creation of spans RDF
		if @job
			active_job = CreateSpansRdfCollectionJob.perform_later(collection)
			monitor_job = active_job.create_job_record(collection.jobs, "Create Spans RDF Collection- #{collection.name}")
			until monitor_job.finished_live?
				sleep(1)
				ActiveRecord::Base.connection.clear_query_cache
			end
		else
			puts "start creation <====="
			CreateSpansRdfCollectionJob.perform_now(collection)
		end

		@job.increment!(:num_dones, 1) if @job
	end

	def forced?(options)
		options && options.has_key?(:forced) ? options[:forced] == true : false
	end
end
