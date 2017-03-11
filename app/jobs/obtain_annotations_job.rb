class ObtainAnnotationsJob < Struct.new(:project, :docids, :annotator, :options)
	include StateManagement

	def perform
		@job.update_attribute(:num_items, docids.length)
    @job.update_attribute(:num_dones, 0)

    # for asyncronous annotation
    max_trials = 3
    retrieval_queue = []
    @skip_interval = nil

    docids.each_with_index do |docid, i|
      doc = Doc.find(docid)

      begin
        project.obtain_annotations(doc, annotator, options)
        trials = nil
        @job.update_attribute(:num_dones, i + 1)
      rescue RestClient::Exceptions::Timeout => e
        @job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: "Job execution stopped: #{e.message}"})
        break
      rescue RestClient::ExceptionWithResponse => e
        if e.response.code == 303
          retry_after = e.response.headers[:retry_after].to_i
          @skip_interval ||= [retry_after / 2, 1].max
          retrieval_queue << {doc:doc, url:e.response.headers[:location], num_tries: max_trials - 1, try_at: retry_after.seconds.from_now, retry_after: retry_after}
          trials = nil
        elsif e.response.code == 503
          if retrieval_queue.empty?
            @job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: "Job execution stopped: service is unavailable when the queue is empty."})
            break
          else
            min_time = retrieval_queue.min_by{|t| t[:try_at]}[:try_at]
            sleep(min_time - Time.now > 0 ? min_time - Time.now : @skip_interval)
            process_retrieval_queue(retrieval_queue)
            trials ||= 0
            retry if (trials += 1) < max_trials
            @job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: "Annotation request stopped: service is unavailable (tried #{max_trials} times)."})
            break
          end
        else
          @job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
        end
      rescue => e
				@job.messages << Message.create({sourcedb: doc.sourcedb, sourceid: doc.sourceid, divid: doc.serial, body: e.message})
        break
      end

      process_retrieval_queue(retrieval_queue) unless retrieval_queue.empty?
    end

    until retrieval_queue.empty?
      sleep(@skip_interval)
      process_retrieval_queue(retrieval_queue)
    end
	end

  def process_retrieval_queue(queue)
    queue.each do |r|
      if r[:try_at] < Time.now
        begin
          annotations = project.make_request(r[:doc], :get, r[:url], nil, nil, options)
          Annotation.normalize!(annotations, options[:abbrev])
          project.save_annotations(annotations, r[:doc], options)
          @job.update_attribute(:num_dones, @job.num_dones + 1)
          r[:delme] = true
        rescue RestClient::ExceptionWithResponse => e
          if e.response.code == 404 # Not Found
            if (r[:num_tries]-=1).zero?
              @job.messages << Message.create({sourcedb: r[:doc].sourcedb, sourceid: r[:doc].sourceid, divid:r[:doc].serial, body: "Retrieval of annotation failed despite of several trials."})
              r[:delme] = true
            else
              r[:try_at] = @skip_interval.seconds.from_now
            end
          elsif e.response.code == 410 # Permanently removed
            @job.messages << Message.create({sourcedb: r[:doc].sourcedb, sourceid: r[:doc].sourceid, divid: r[:doc].serial, body: "Annotation result is removed from the server."})
            r[:delme] == true
          else
            @job.messages << Message.create({sourcedb: r[:doc].sourcedb, sourceid: r[:doc].sourceid, divid: r[:doc].serial, body: e.message})
          end
        rescue => e
          @job.messages << Message.create({sourcedb: r[:doc].sourcedb, sourceid: r[:doc].sourceid, divid: r[:doc].serial, body: e.message})
        end
      end
    end

    queue.delete_if{|r| r[:delme]}
  end
end
