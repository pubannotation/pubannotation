class RetrieveAnnotationsJob < Struct.new(:project, :doc, :url, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, 1)
    @job.update_attribute(:num_dones, 0)

    begin
      annotations = project.make_request(doc, :get, url, nil, nil, options)
	    Annotation.normalize!(annotations, options[:abbrev])
	    project.save_annotations(annotations, doc, options)
    rescue RestClient::ExceptionWithResponse => e
      if e.response.code == 404 #Not Found
				options[:try_times] -= 1
      	if options[:try_times] > 0
	        priority = project.jobs.unfinished.count
	        delayed_job = Delayed::Job.enqueue RetrieveAnnotationsJob.new(project, doc, url, options), priority: priority, queue: :general, run_at: options[:retry_after].seconds.from_now
	        Job.create({name:"Retrieve annotations", project_id:project.id, delayed_job_id:delayed_job.id})
					@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: "Not available. Will try #{options[:try_times]} more time(s)."})
	      else
					@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: "Retrieval of annotation failed."})
	      end
      else
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
      end
    rescue => e
			@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
    end

		@job.update_attribute(:num_dones, 1)
	end
end
