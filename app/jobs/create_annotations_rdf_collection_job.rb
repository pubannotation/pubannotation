class CreateAnnotationsRdfCollectionJob < Struct.new(:collection, :options)
	include StateManagement

	def perform
		if @job
			@job.update_attribute(:num_items, collection.primary_projects.count + 1)
			@job.update_attribute(:num_dones, 0)
		end

		FileUtils.mkdir_p collection.annotations_rdf_dirpath unless File.exists? collection.annotations_rdf_dirpath
		FileUtils.rm_f Dir.glob("#{collection.annotations_rdf_dirpath}/*")

		# creation of annotations RDF
		collection.primary_projects.each do |project|
			if forced? || project.rdf_needs_to_be_updated?
				if @job
					delayed_job = Delayed::Job.enqueue CreateAnnotationsRdfJob.new(project), queue: :general
					monitor_job = collection.jobs.create({name:"Create Annotation RDF - #{project.name}", delayed_job_id:delayed_job.id})
					sleep(1) until monitor_job.finished_live?
				else
					puts "start creation, #{project.name} <====="
					creation_job = CreateAnnotationsRdfJob.new(project)
					creation_job.perform
				end
			end
			FileUtils.ln_sf(project.annotations_trig_filepath, collection.annotations_rdf_dirpath)
			@job.increment!(:num_dones, 1) if @job
		rescue => e
			if @job
				@job.messages << Message.create({body: e.message})
			else
				raise e
			end
		end

		# creation of spans RDF
		if @job
			delayed_job = Delayed::Job.enqueue CreateSpansRdfCollectionJob.new(collection), queue: :general
			monitor_job = collection.jobs.create({name:"Create Spans RDF Collection- #{collection.name}", delayed_job_id:delayed_job.id})
			sleep(1) until monitor_job.finished_live?
		else
			puts "start creation <====="
			creation_job = CreateSpansRdfCollectionJob.new(collection)
			creation_job.perform
		end

		@job.increment!(:num_dones, 1) if @job
	end

	def forced?
		options && options.has_key?(:forced) ? options[:forced] == true : false
	end

end
