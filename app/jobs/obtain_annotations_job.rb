class ObtainAnnotationsJob < Struct.new(:project, :docids, :annotator, :options)
	include StateManagement

  MaxTrials = 10

	def perform
		@job.update_attribute(:num_items, docids.length)
    @job.update_attribute(:num_dones, 0)

    # for asyncronous annotation
    trials = nil
    retrieval_queue = []
    @skip_interval = nil

    batch_num = annotator[:batch_num]
    batch_num = 1 if batch_num.nil? || batch_num == 0

    docids.each_slice(batch_num) do |docid_col|
      begin
        project.obtain_annotations(docid_col, annotator, options)
        trials = nil
        @job.update_attribute(:num_dones, @job.num_dones + docid_col.length)
      rescue RestClient::Exceptions::Timeout => e
        @job.messages << Message.create({body: "Job execution stopped: #{e.message}"})
        break
      rescue RestClient::ExceptionWithResponse => e
        if e.response.code == 303
          retry_after = e.response.headers[:retry_after].to_i
          @skip_interval ||= [retry_after / 2, 1].max
          retrieval_queue << {url:e.response.headers[:location], trials: 1, try_at: retry_after.seconds.from_now, retry_after: retry_after}
          trials = nil
        elsif e.response.code == 503
          if retrieval_queue.empty?
            @job.messages << Message.create({body: "Job execution stopped: service is unavailable when the queue is empty."})
            break
          else
            trials ||= 1
            min_time = retrieval_queue.min_by{|t| t[:try_at]}[:try_at]
            sleep_time = [min_time - Time.now, @skip_interval].max * trials
            sleep(sleep_time)
            process_retrieval_queue(retrieval_queue)
            retry if (trials += 1) <= MaxTrials
            @job.messages << Message.create({body: "Annotation request stopped: service is unavailable (tried #{MaxTrials} times)."})
            break
          end
        else
          @job.messages << Message.create({body: e.message})
        end
      rescue => e
				@job.messages << Message.create({body: e.message})
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
          result = project.make_request(:get, r[:url])
          annotations_col = (result.class == Array) ? result : [result]

          annotations_col.each_with_index do |annotations, i|
            raise RuntimeError, "Invalid annotation JSON object." unless annotations.respond_to?(:has_key?)
            Annotation.normalize!(annotations, options[:prefix])
          end

          messages = project.store_annotations_collection(annotations_col, options)
          messages.each{|message| @job.messages << Message.create(message)}

          @job.update_attribute(:num_dones, @job.num_dones + annotations_col.length)
          r[:delme] = true
        rescue RestClient::ExceptionWithResponse => e
          if e.response.code == 404 # Not Found
            if (r[:trials]+=1) > MaxTrials
              @job.messages << Message.create({body: "Retrieval of annotation failed despite of #{MaxTrials} trials."})
              r[:delme] = true
            else
              r[:try_at] = @skip_interval.seconds.from_now
            end
          elsif e.response.code == 410 # Permanently removed
            @job.messages << Message.create({body: "Annotation result is removed from the server."})
            r[:delme] == true
          else
            @job.messages << Message.create({body: e.message})
          end
        rescue => e
          @job.messages << Message.create({body: e.message})
        end
      end
    end

    queue.delete_if{|r| r[:delme]}
  end
end
