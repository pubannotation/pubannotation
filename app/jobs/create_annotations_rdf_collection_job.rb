class CreateAnnotationsRdfCollectionJob < ApplicationJob
	queue_as :low_priority

	def perform(collection, options)
		if @job
			prepare_progress_record(collection.primary_projects.count + collection.secondary_projects.count + 2)
		end

		FileUtils.mkdir_p collection.rdf_dirpath unless File.exists? collection.rdf_dirpath
		FileUtils.rm_f Dir.glob("#{collection.rdf_dirpath}/*")
		FileUtils.rm_f collection.rdf_zippath

		## create annotation RDF of primary projects
		create_annotation_RDF(collection, collection.primary_projects, options)

		## create annotation RDF of secondary projects
		unless collection.secondary_projects.empty?
			primary_doc_ids = [].union(collection.primary_projects.collect{|project| project.docs.pluck(:id)})
			create_annotation_RDF(collection, collection.secondary_projects, options, primary_doc_ids)
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

		puts "start creation of collection RDF zip <====="
		collection.create_RDF_zip
		@job.increment!(:num_dones, 1) if @job
	end

	def create_annotation_RDF(collection, projects, options, doc_ids = nil)
		pp projects
		puts "start creation of annotation RDF <============"
		projects.each do |project|
			if forced?(options) || project.rdf_needs_to_be_updated?
				if @job
					active_job = CreateAnnotationsRdfJob.perform_later(project)
					monitor_job = Job.find_by(active_job_id: active_job.job_id)
					until monitor_job.finished_live?
						sleep(1)
						ActiveRecord::Base.connection.clear_query_cache
					end
				else
					puts "start creation, #{project.name} <====="
					CreateAnnotationsRdfJob.perform_now(project)
				end
			end
			FileUtils.ln_sf(project.annotations_trig_filepath, collection.rdf_dirpath)
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
	end

	def forced?(options)
		options && options.has_key?(:forced) ? options[:forced] == true : false
	end

	def job_name
		"Create Annotation RDF Collection - #{resource_name}"
	end
end
